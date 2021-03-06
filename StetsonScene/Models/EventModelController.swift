//
//  EventModelController.swift
//  StetsonScene
//
//  Created by Lannie Hough on 1/29/20.
//  Copyright © 2020 Lannie Hough. All rights reserved.

import Foundation
import SwiftUI
import Firebase
import FirebaseDatabase
import CoreData
import EventKit

//
enum SuccessCheck {
    case success, error
}

/// ViewModel class for MVVM design pattern.  A single instance is created and injected into various views.
class EventViewModel: ObservableObject {
    
    //var config: Configuration = Configuration(EventViewModel())
    
    var hasObtainedAssociations:Bool = false //Determines if listeners have been put on event and location association nodes
    var eventSearchEngine = EventSearchEngine()
    
    //List of EventInstance objects representing live events loaded into the app from the backend
    @Published var eventList:[EventInstance] = []
    //Dictionary of all EventInstance objects
    var eventDictionary:Dictionary<String, EventInstance> = [:] //Allows directly accessing EventInstance objects by guid
    
    //Persistent event data only stores data for certain properties for simplicity and other practical reasons.  These are properties that are only relevant to the user's version of these events, other properties might change by event organizers or other app users.  This struct mimics the SigEventData entity model used in Core Data.
    struct SigEventData {
        let guid:String
        let isAttending:Bool
        let isFavorite:Bool
        let isInCalendar:Bool
    }
    
    var significantDictionary:Dictionary<String, SigEventData> = [:] //Set of representations of persistent event data.  Reading from Core Data will write to this set.  After data is read from the database the event representation will be cross-referenced against this for persistent information.
    
    //Dictionaries that associate sublocations and event subtypes with their parent types
    //ex: Room 210 is a sublocation for Elizabeth Hall
    var eventTypeAssociations:Dictionary<String, Any> = [:]
    var locationAssociations:Dictionary<String, Any> = [:]
    @Published var eventTypeList:[String] = []//Used to contain event types or locations that the user cares about
    //Unlike eventTypeSet used in searching which only contains what is being filtered on, eventTypeSetFull contains all possible event types
    @Published var eventTypeSetFull:Set<String> = []
    @Published var locationList:[String] = []
    @Published var locationSetFull:Set<String> = []
    
    @Published var buildingModelController = BuildingModelController()
    
    //When events are loaded into the app listeners are put on their numberAttending node to keep this updated live between all users, this set is used to prevent duplicate listeners
    var beingObservedSet:Set<String> = []
    
    //Indicates how many weeks worth of database info are currently loaded into the app to prevent unnecessary database queries
    var weeksStored:Int = 1
    @Published var dataReturnedFromSnapshot:Bool = false
    @Published var hasFirebaseConnection = true
    
    private enum ParentChildRelationship {
        case eventType
        case location
    }
    
    ///Function takes an event subtype & returns the "parent" event type.  Helper search function.
    private func associateParentType(childType: String, eventTypeOrLocation: ParentChildRelationship) -> String {
        var dictionary:Dictionary<String, Any> = [:]
        if eventTypeOrLocation == .eventType {
            dictionary = eventTypeAssociations
        } else if eventTypeOrLocation == .location {
            dictionary = locationAssociations
        }
        for (k, v) in dictionary {
            for (key, _) in (v as? Dictionary<String, String>)! {
                if key == childType {
                    return k
                }
            }
        }
        return childType
    }
    
    // ===== FAVORITE / CALENDAR FUNCTIONS & EVENT DATA PERSISTENCE ===== //
    
    /*
     Favoriting an event or adding an event to the calendar app should result in number attending going up locally and updating the database with a new attendee.  If the user cannot connect to the database, store this information and change the database later.  If isFavorite or isInCalendar is true, isAttending should also be true.  Favorite/calendar events will be loaded into the app regardless of other time constraints so that they can be displayed in the user's favorite list - they are directly queried.
     */
    
    //Loads stored persistent data into significantDictionary object
    func loadPersistentEventData() {
        self.significantDictionary = [:]
        let appDelegate = AppDelegate.shared()
        let managedContext = appDelegate.persistentContainer.viewContext
        let fetchReq = NSFetchRequest<NSFetchRequestResult>(entityName: "SigEventData")
        do {
            let result = try managedContext.fetch(fetchReq)
            for data in result as! [NSManagedObject] {
                let guid = data.value(forKey: "guid") as? String
                let isAttending = data.value(forKey: "isAttending") as? Bool
                let isInCalendar = data.value(forKey: "isInCalendar") as? Bool
                let isFavorite = data.value(forKey: "isFavorite") as? Bool
                self.significantDictionary[guid!] = SigEventData(guid: guid!, isAttending: isAttending!, isFavorite: isFavorite!, isInCalendar: isInCalendar!)
            }
        } catch {
            print("Failed to load persistent data!")
            print(error)
        }
    }
    
    //Function is called to add an event representation to persistent data - the logic of when this should happen is handled in manageAttendingProperties.
    func createPersistentData(eI: EventInstance) {
        let appDelegate = AppDelegate.shared()
        let managedContext = appDelegate.persistentContainer.viewContext
        let newPersistentEntity = NSEntityDescription.entity(forEntityName: "SigEventData", in: managedContext)!
        let newPersistent = NSManagedObject(entity: newPersistentEntity, insertInto: managedContext)
        newPersistent.setValue(eI.isFavorite, forKey: "isFavorite")
        newPersistent.setValue(eI.isInCalendar, forKey: "isInCalendar")
        newPersistent.setValue(eI.isAttending, forKey: "isAttending")
        newPersistent.setValue(eI.guid, forKey: "guid")
        do {
            try managedContext.save()
        } catch let error as NSError {
            print("Could not save. \(error)")
        }
    }
    
    //Function is called to remove an event representation from persistent data - the logic of when this should happen is handled in manageAttendingProperties.
    func removePersistentData(guid: String) {
        let appDelegate = AppDelegate.shared()
        let managedContext = appDelegate.persistentContainer.viewContext
        let fetchReq = NSFetchRequest<NSFetchRequestResult>(entityName: "SigEventData")
        //Only fetches entities with guid matching the guid of the event we want to remove
        fetchReq.predicate = NSPredicate(format: "guid = %@", guid)
        do {
            let test = try managedContext.fetch(fetchReq)
            //test is an array, but because we are filtering by guid it should only contain one element at [0]
            let toDelete = test[0] as! NSManagedObject
            managedContext.delete(toDelete)
            do {
                try managedContext.save()
            } catch {
                print(error)
            }
        } catch {
            print(error)
        }
    }
    
    //Modifies event representations in persistent data.
    func updatePersistentData(guidToUpdate: String, favoriteTrueFalse: Bool, calendarTrueFalse: Bool) {
        let appDelegate = AppDelegate.shared()
        let managedContext = appDelegate.persistentContainer.viewContext
        let fetchReq = NSFetchRequest<NSFetchRequestResult>(entityName: "SigEventData")
        //Only fetches entities with guid matching the guid of the event we want to modify
        fetchReq.predicate = NSPredicate(format: "guid = %@", guidToUpdate)
        do {
            let test = try managedContext.fetch(fetchReq)
            let toModify = test[0] as! NSManagedObject
            toModify.setValue(favoriteTrueFalse, forKey: "isFavorite")
            toModify.setValue(calendarTrueFalse, forKey: "isInCalendar")
            //if this event has been favorited OR added to calendar, persistent "isAttending" should be made true
            let attendingVal = (favoriteTrueFalse || calendarTrueFalse) ? true : false
            toModify.setValue(attendingVal, forKey: "isAttending")
            do {
                try managedContext.save()
            } catch {
                print(error)
            }
        } catch {
            print(error)
        }
    }
    
    //Checks if an event has a representation in persistent data already
    func isInPersistentData(guid: String) -> Bool {
        let appDelegate = AppDelegate.shared()
        let managedContext = appDelegate.persistentContainer.viewContext
        let fetchReq = NSFetchRequest<NSFetchRequestResult>(entityName: "SigEventData")
        fetchReq.predicate = NSPredicate(format: "guid = %@", guid)
        do {
            let test = try managedContext.fetch(fetchReq)
            return test.isEmpty ? false : true
        } catch {
            print("Failed to fetch an event representation with specified guid!")
            print(error)
        }
        return false
    }
    
    //Returns significant data from the persistent dictionary in the form of an attending, favorite, calendar tuple
    func returnSigPersistentData(guid: String) -> (Bool, Bool, Bool) {
        return (self.significantDictionary[guid]!.isAttending, self.significantDictionary[guid]!.isFavorite, self.significantDictionary[guid]!.isInCalendar)
    }
    
    func toggleFavorite(_ event: EventInstance) {
        if self.canHitFavorites {
            haptic()
            self.timeDelayFavoriteHit()
            self.managePersistentProperties(event, updateFavoriteState: true, updateCalendarState: false)
            let tempEvent = self.eventList[self.eventList.count-1] //Force updates to views that watch the list - mostly to update favorite view when an event changes favorite state
            self.eventList.removeLast()
            self.eventList.append(tempEvent)
        }
    }
    
    enum NumAttendingState {
        case inc
        case dec
        case same
    }
    
    func managePersistentProperties(_ event: EventInstance, updateFavoriteState: Bool, updateCalendarState: Bool) {
        
        let prevAttendState = event.isAttending
        let prevFavState = event.isFavorite
        let prevCalState = event.isInCalendar
        
        event.isFavorite = updateFavoriteState ? !event.isFavorite : event.isFavorite
        event.isInCalendar = updateCalendarState ? !event.isInCalendar : event.isInCalendar
        event.isAttending = (event.isFavorite || event.isInCalendar) ? true : false
        
        var incDec:NumAttendingState = .same
        if prevAttendState && !(prevFavState && prevCalState) { //If was previously attending and only one of calendar and fav is selected, decrement
            incDec = updateFavoriteState ? (updateFavoriteState == prevFavState ? .dec : .same)  : (updateCalendarState == prevCalState ? .dec : .same)
            //incDec = .dec
        } else if prevAttendState && (prevFavState && prevCalState) { //If was previously attending and both were selected, do nothing
            incDec = .same
        } else {
            incDec = .inc
        }
        
        if incDec != .same {
            self.updateNumberAttending(guid: event.guid, incDec: incDec == .inc ? true : false) //If was not previously attending, increment number attending
        }
        
        if event.isAttending {
            if !self.isInPersistentData(guid: event.guid) { //If does not exist in persistent data and attending, add to persistent
                self.createPersistentData(eI: event)
            } else { //If already in persistent data with different data, modify persistent
                self.updatePersistentData(guidToUpdate: event.guid, favoriteTrueFalse: event.isFavorite, calendarTrueFalse: event.isInCalendar)
            }
        } else {
            if self.isInPersistentData(guid: event.guid) { //If in persistent data but now user is not attending, remove from persistent
                self.removePersistentData(guid: event.guid)
            }
        }
        self.loadPersistentEventData()
    }
    
    func manageCalendar(_ event: EventInstance) -> ActionSheet {
        let doesEventExist:Bool = self.doesEventExist(store: EKEventStore(), title: event.name, date: event.date, time: event.time, endDate: event.endDate, endTime: event.endTime)
        if !doesEventExist && event.isInCalendar { //Can happen if event is removed from calendar while app is running
            self.managePersistentProperties(event, updateFavoriteState: false, updateCalendarState: true)
        }
        if doesEventExist { //event already exists
            return ActionSheet(title: Text("Whoops!"), message: Text("You already have this event in your calendar!"), buttons: [.destructive(Text("Dismiss"), action: {})])
        } else { //event does not already exist
            return ActionSheet(title: Text("Add event?"), message: Text("Would you like to add an alert when this event is about to happen?"),
                               buttons: [.default(Text("Save with alert"), action: {
                                let eventStore = EKEventStore()
                                switch EKEventStore.authorizationStatus(for: .event) {
                                case .authorized:
                                    self.manageCalendarInsertion(event: event, eventStore: eventStore, saveWithAlert: true)
                                case .denied:
                                    print("Access denied")
                                case .notDetermined:
                                    eventStore.requestAccess(to: .event, completion:
                                        {[self] (granted: Bool, error: Error?) -> Void in
                                            if granted {
                                                self.manageCalendarInsertion(event: event, eventStore: eventStore, saveWithAlert: true)
                                            } else {
                                                print("Access denied")
                                            }
                                    })
                                default:
                                    print("Case default")
                                }
                               }),
                                         .default(Text("Save without alert"), action: {
                                            let eventStore = EKEventStore()
                                            switch EKEventStore.authorizationStatus(for: .event) {
                                            case .authorized:
                                                self.manageCalendarInsertion(event: event, eventStore: eventStore, saveWithAlert: false)
                                            case .denied:
                                                print("Access denied")
                                            case .notDetermined:
                                                eventStore.requestAccess(to: .event, completion:
                                                    {[self] (granted: Bool, error: Error?) -> Void in
                                                        if granted {
                                                            self.manageCalendarInsertion(event: event, eventStore: eventStore, saveWithAlert: false)
                                                        } else {
                                                            print("Access denied")
                                                        }
                                                })
                                            default:
                                                print("Case default")
                                            }
                                         }),
                                         .destructive(Text("Cancel"), action: {
                                         })])
        }
    }
    
    func manageCalendarInsertion(event: EventInstance, eventStore: EKEventStore, saveWithAlert: Bool) {
        self.insertEvent(store: eventStore, title: event.name, date: event.date, time: event.time, endDate: event.endDate, endTime: event.endTime, saveWithAlert: saveWithAlert)
        self.managePersistentProperties(event, updateFavoriteState: false, updateCalendarState: true)
    }
    
    ///Inserts events into the user's calendar.
    func insertEvent(store: EKEventStore, title: String, date: String, time: String, endDate: String, endTime: String, saveWithAlert: Bool) {
        let calendar = store.defaultCalendarForNewEvents
        let event = EKEvent(eventStore: store)
        event.calendar = calendar
        event.title = title
        event.startDate = makeDateComponents(day: date, time: time)
        event.endDate = makeDateComponents(day: endDate, time: endTime)
        if saveWithAlert { //should or should not save with an alert
            let alarm = EKAlarm(relativeOffset: TimeInterval(-30*60)) //30 minutes before event start
            event.addAlarm(alarm)
        }
        let alreadyExists = doesEventExist(store: store, title: title, date: date, time: time, endDate: endDate, endTime: endTime)
        if !alreadyExists {
            do {
                try store.save(event, span: .thisEvent)
                print("Successfully saved event.")
            } catch {
                print("Error saving event.")
            }
        } else {
            print("Event already exists.")
        }
    }
    
    ///Makes DateComponents object that can then be used in putting events on the user's calendar at the right time.
    func makeDateComponents(day: String, time: String) -> Date {
        let eventDate:Date
        
        let formatter = DateFormatter()
        formatter.dateFormat = "MM/dd/yyyy h:mm a"
        formatter.timeZone = TimeZone(abbreviation: "EST")
        let dateToUse = day + " " + time
        eventDate = formatter.date(from: dateToUse)!
        print()
        
        return eventDate
    }
    
    ///Called when attempting to add events to calendar to determine if the event already exists & deny adding if this is the case.
    func doesEventExist(store: EKEventStore, title: String, date: String, time: String, endDate: String, endTime: String) -> Bool {
        let calendar = store.defaultCalendarForNewEvents
        let event = EKEvent(eventStore: store)
        event.calendar = calendar
        event.title = title
        event.startDate = makeDateComponents(day: date, time: time)
        event.endDate = makeDateComponents(day: endDate, time: endTime)
        
        let predicate = store.predicateForEvents(withStart: makeDateComponents(day: date, time: time), end: makeDateComponents(day: endDate, time: endTime), calendars: nil)
        let existingEvents = store.events(matching: predicate)
        let alreadyExists = existingEvents.contains(where: {e in e.title == event.title && e.startDate == event.startDate && e.endDate == event.endDate})
        
        if alreadyExists {
            return true
        } else {
            return false
        }
    }
    
    // ===== FIREBASE FUNCTIONS ===== //
    
    enum DataState {
        case valid
        case invalid
    }
    
    func insertEventListDic(_ event: EventInstance) {
        self.eventDictionary[event.guid!] = event
        if self.eventList.count == 0 {
            self.eventList.append(event)
            return
        }
        if self.eventList.count == 1 {
            if !(event.startDateTimeInfo > self.eventList[0].startDateTimeInfo) {
                self.eventList.insert(event, at: 0)
                return
            } else {
                self.eventList.append(event)
                return
            }
        }
        for i in 0 ..< self.eventList.count {
            // > returns true if first date/time is later than second date, false if else
            if !(event.startDateTimeInfo > self.eventList[i].startDateTimeInfo) {
                self.eventList.insert(event, at: i)
                return
            }
        }
        self.eventList.append(event)
    }
    
    func updateNumberAttending(guid: String, incDec: Bool) {
        let ref:DatabaseReference = AppDelegate.shared().eventListRef.child(guid)
        var numAttending:Int = 0
        ref.observeSingleEvent(of: .value, with: { (snapshot) in
            if snapshot.value != nil { //if nil, event has presumably been removed from database/Firebase
                let event = (snapshot.value as? Dictionary<String, Any>)!
                numAttending = (event["numberAttending"] as? Int)!
                numAttending += incDec ? 1 : -1
                ref.child("numberAttending").setValue(numAttending)
            }
        })
    }
    
    var canHitFavorites = true
    ///Function prevents "spamming" of the favorite button, which can cause erroneous Firebase input
    func timeDelayFavoriteHit() {
        canHitFavorites = false
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.55) {
            self.canHitFavorites = true
        }
    }
    
    func retrieveFirebaseDataFavorites(doFilter: Bool, searchEngine: EventSearchEngine, filterOnlyTime: Bool) {
        //
        for (k, _) in self.significantDictionary {
            if self.eventDictionary[k] == nil { //Favorite that we know exists from persistent storage is not in main event list - query Firebase for it
                print("Persistent event not in app")
                AppDelegate.shared().eventListRef.queryOrdered(byChild: "guid").queryEqual(toValue: k).observeSingleEvent(of: .value, with: { snapshot in
                    if snapshot.value != nil { //if nil, event has presumably been removed from database/Firebase
                        let e = snapshot.value as? Dictionary<String, Any>
                        if e == nil {
                            return
                        }
                        if e![k] == nil {
                            return
                        }
                        var newInstance:EventInstance
                        let newData = self.readEventData(eventData: e![k]! as! Dictionary<String, Any>)
                        if newData.1 == .invalid {
                            return
                        } else {
                            newInstance = newData.0
                            
                            if newInstance.location == "" || newInstance.location == "Default location" {
                                if self.checkIsVirtual(event: newInstance) {
                                    newInstance.location = "Virtual"
                                }
                            }
                            
                        }
                        //add observer to numberAttending so that this information can update live in detail views
                        if !self.beingObservedSet.contains(newInstance.guid) {
                            AppDelegate.shared().eventListRef.child(newInstance.guid).child("numberAttending").observe(.value, with: { snapshot in
                                newInstance.numAttending = snapshot.value as? Int
                                self.beingObservedSet.insert(newInstance.guid)
                            })
                        }
                        self.insertEventListDic(newInstance)
                        if doFilter {
                            if !filterOnlyTime {
                                self.eventSearchEngine.checkEvent(newInstance, self)
                            } else {
                                print5("fav filter only time")
                                self.eventSearchEngine.checkEvent(newInstance, self, checkOnlyTime: filterOnlyTime)
                            }
                        }
                        //self.favEventSet[newInstance.guid] = newInstance //make reference to this event in favorite dictionary using its guid as a key
                    }
                })
            }
        }
    }
    
    func retrieveFirebaseData(daysIntoYear: Int, doFilter: Bool, searchEngine: EventSearchEngine, filterOnlyTime: Bool = false) {
        self.dataReturnedFromSnapshot = false
        //Prevent duplicate observers
        AppDelegate.shared().eventListRef.removeAllObservers()
        AppDelegate.shared().updateListRef.removeAllObservers()
        self.loadPersistentEventData()
        self.eventList = []
        self.eventDictionary = [:]
        //self.retrieveFirebaseDataFavorites(doFilter: doFilter, searchEngine: searchEngine)
        AppDelegate.shared().updateListRef.observe(.value, with: { (snapshot) in
            self.eventList = []
            self.eventDictionary = [:]
//            self.beingObservedSet = []
            // bugs - favoriting in future, then triggering new load from firebase, doubles favorited events
            // also, favorites in future are loaded even though they shouldnt be
            AppDelegate.shared().eventListRef.queryOrdered(byChild: "daysIntoYear").queryEnding(atValue: daysIntoYear).observeSingleEvent(of: .value, with: { snapshot in
                let fullEventList = snapshot.value as? Dictionary<String, Dictionary<String, Any>>
                //print(fullEventList)
                for (_, v) in fullEventList! {
                    let newInstanceCheck = self.readEventData(eventData: v)
                    if newInstanceCheck.1 == .invalid {
                        continue
                    } else {
                        
                        if newInstanceCheck.0.location == "" || newInstanceCheck.0.location == "Default location" {
                            if self.checkIsVirtual(event: newInstanceCheck.0) {
                                newInstanceCheck.0.location = "Virtual"
                            }
                        }
                        
                        if self.eventDictionary[newInstanceCheck.0.guid] == nil {
                            self.insertEventListDic(newInstanceCheck.0)
                        }
                        AppDelegate.shared().eventListRef.child(newInstanceCheck.0.guid).child("numberAttending").observe(.value, with: { snapshot in
                            newInstanceCheck.0.numAttending = snapshot.value as? Int
                            self.beingObservedSet.insert(newInstanceCheck.0.guid)
                        })
                        if doFilter {
                            if !filterOnlyTime {
                                self.eventSearchEngine.checkEvent(newInstanceCheck.0, self)
                            } else {
                                print5("filter only time")
                                self.eventSearchEngine.checkEvent(newInstanceCheck.0, self, checkOnlyTime: filterOnlyTime)
                            }
                        }
                    }
                }
                self.retrieveFirebaseDataFavorites(doFilter: doFilter, searchEngine: searchEngine, filterOnlyTime: filterOnlyTime)
                self.dataReturnedFromSnapshot = true
            })
        })
        if !hasObtainedAssociations {
            AppDelegate.shared().eventTypeAssociationRef.observe(.childAdded) { snapshot in
                self.eventTypeList.append(snapshot.key)
                self.eventTypeSetFull.insert(snapshot.key)
                //self.displayEventTypeList.append(true)
                self.eventTypeAssociations[snapshot.key] = snapshot.value as? Dictionary<String, String>
                //print(self.eventTypeAssociations)
            }
        
            AppDelegate.shared().locationAssocationRef.observe(.childAdded) { snapshot in
                self.locationList.append(snapshot.key)
                self.locationSetFull.insert(snapshot.key)
                self.locationAssociations[snapshot.key] = snapshot.value as? Dictionary<String, String>
            }
        }
        hasObtainedAssociations = true
    }
    
    //Persistent coords stored as ["Building", "10.0:-5.0"]
    var persistentLocations:Dictionary<String, String> = {
        return UserDefaults.standard.object(forKey: "persistentLocations") != nil ?
            UserDefaults.standard.object(forKey: "persistentLocations") as! Dictionary<String, String> : [:]
    }() {
        didSet {
            UserDefaults.standard.set(self.persistentLocations, forKey: "persistentLocations")
        }
    }
    
    func readEventData(eventData: Dictionary<String, Any>) -> (EventInstance, DataState) {
        let newInstance = EventInstance()
        for (k, v) in eventData {
            switch k {
            case "absolutePosition":
                newInstance.absolutePosition = (v as? Int)! //Unused at present
            case "guid":
                newInstance.guid = (v as? String) ?? "" //Highly unlikely to occur
                if newInstance.guid == "" { return (newInstance, .invalid) }
            case "name":
                newInstance.name = (v as? String) ?? "Default name"
            case "time":
                newInstance.time = (v as? String) ?? "Default time"
            case "date":
                newInstance.date = (v as? String) ?? "Default date"
            case "endDate":
                newInstance.endDate = (v as? String) ?? "Default end date"
            case "endTime":
                newInstance.endTime = (v as? String) ?? "Default end time"
            case "daysIntoYear":
                newInstance.daysIntoYear = (v as? Int) ?? 0
            case "numberAttending":
                newInstance.numAttending = (v as? Int) ?? 0
            case "url":
                newInstance.url = (v as? String) ?? "Default url"
            case "summary":
                newInstance.summary = (v as? String) ?? "Default summary"
            case "description":
                newInstance.eventDescription = (v as? String) ?? "Default description"
            case "contactName":
                newInstance.contactName = (v as? String) ?? "Default contact name"
            case "contactPhone":
                newInstance.contactPhone = (v as? String) ?? "Default contact phone"
            case "contactMail":
                newInstance.contactMail = (v as? String) ?? "Default contact mail"
            case "mainLocation":
                newInstance.location = (v as? String) ?? "Default location"
            case "mainEventType":
                newInstance.mainEventType = (v as? String) ?? "Default main event type"
            case "address":
                newInstance.mainAddress = (v as? String) ?? "Default address"
            case "city":
                newInstance.mainCity = (v as? String) ?? "Default city"
            case "zip":
                newInstance.mainZip = (v as? String) ?? "Default zip"
            case "lat":
                let tempLat = (v as? String) ?? "0.0"
                newInstance.mainLat = (Double(tempLat) != nil) ? Double(tempLat) : 0.0
            case "lon":
                let tempLon = (v as? String) ?? "0.0"
                newInstance.mainLon = (Double(tempLon) != nil) ? Double(tempLon) : 0.0
            case "hasCultural":
                newInstance.hasCultural = (v as? Bool) ?? false
            case "subLocations":
                for loc in v as? [String] ?? ["Default string"] {
                    newInstance.locations.append(loc)
                }
            case "eventTypes":
                for ev in v as? [String] ?? ["Default string"] {
                    newInstance.eventType.append(ev)
                }
            default:
                break;
            }
            
        }
        
        print(self.persistentLocations)
        
        if persistentLocations[newInstance.location!] == nil && !self.checkBadCoords(String(newInstance.mainLat!)) {
            let saveCoords = String(newInstance.mainLat!) + ":" + String(newInstance.mainLon!)
            persistentLocations[newInstance.location!] = saveCoords
        }
        
        if newInstance.location!.lowercased() != "virtual" && self.checkBadCoords(String(newInstance.mainLat!)) {
            if persistentLocations[newInstance.location!] != nil {
                let coords = persistentLocations[newInstance.location!]?.components(separatedBy: ":")
                let lat:String = coords![0]
                let lon:String = coords![1]
                newInstance.mainLat = Double(lat)
                newInstance.mainLon = Double(lon)
            }
        }
        
        //Convert strings relating to date and time to a DateTimeInfo object - if this cannot be done, the event data is invalid because users wouldn't know when the event is occuring.
        let dateTimeInfoStart = makeDateTimeInfo(dateStr: newInstance.date, timeStr: newInstance.time)
        let dateTimeInfoEnd = makeDateTimeInfo(dateStr: newInstance.endDate, timeStr: newInstance.endTime)
        
        if !dateTimeInfoStart.1 || !dateTimeInfoEnd.1 {
            return (newInstance, .invalid)
        } else {
            newInstance.startDateTimeInfo = dateTimeInfoStart.0
            newInstance.endDateTimeInfo = dateTimeInfoEnd.0
        }
        
        //Add logic here to determine if the event is favorited, in the calendar, or if the user is attending
        if self.significantDictionary[newInstance.guid] != nil {
            newInstance.isFavorite = significantDictionary[newInstance.guid]!.isFavorite
            newInstance.isInCalendar = significantDictionary[newInstance.guid]!.isInCalendar
            newInstance.isAttending = significantDictionary[newInstance.guid]!.isAttending
            let checkCal = self.doesEventExist(store: EKEventStore(), title: newInstance.name, date: newInstance.date, time: newInstance.time, endDate: newInstance.endDate, endTime: newInstance.endTime)
            if checkCal != newInstance.isInCalendar {
                self.managePersistentProperties(newInstance, updateFavoriteState: false, updateCalendarState: true)
            }
        }
        
        return (newInstance, .valid)
    }
    
    func testFirebaseConnection() {
        var lastState:Bool = false
        AppDelegate.shared().connectedRef.observe(.value, with: { snapshot in
            if snapshot.value as? Bool ?? false {
                print("App is connected to FB.")
                self.hasFirebaseConnection = true
                lastState = true
            } else {
                print("App is not connected to FB.")
                lastState = false
                DispatchQueue.main.asyncAfter(deadline: .now() + 5) { //Give some time to attempt connection.
                    if !lastState {
                        self.hasFirebaseConnection = false
                    }
                }
            }
        })
    }
    
    // ===== SUPPORT FUNCTIONS ===== //
    
    func checkBadCoords(_ coord: String) -> Bool {
        if coord == "" || coord == "0.0" || coord == "0" {
            return true
        }
        return false
    }
    
    func makeDateTimeInfo(dateStr: String, timeStr: String) -> (DateTimeInfo, Bool) {
        let dateComponents:(Int, Int, Int, Bool) = {
            let strComp = dateStr.components(separatedBy: "/") // ["3", "14", "2000")
            do {
                return try (getInt(strComp[0]), getInt(strComp[1]), getInt(strComp[2]), true)
            } catch {
                return (0, 0, 0, false)
            }
        }()
        let timeComponents:(Int, Int, AM_PM, Bool) = {
            let strComp = timeStr.components(separatedBy: " ") // ["11:59", "PM"]
            let timeComp = strComp[0].components(separatedBy: ":") // ["11", "59"]
            var valid:Bool = true
            do {
                return try (getInt(timeComp[0]), getInt(timeComp[1]), {
                    if strComp[1] == "AM" {
                        return .am
                    }
                    if strComp[1] == "PM" {
                        return .pm
                    }
                    valid = false
                    return .pm
                }(), valid ? true : false)
            } catch {
                return (0, 0, .pm, false)
            }
        }()
        if !dateComponents.3 || !timeComponents.3 {
            return (DateTimeInfo(year: 0, month: 0, day: 0, hour: 0, minute: 0, am_pm: .pm), false)
        }
        return (DateTimeInfo(year: dateComponents.2, month: dateComponents.0, day: dateComponents.1, hour: timeComponents.0, minute: timeComponents.1, am_pm: timeComponents.2), true)
    }
    
    ///Method takes current number of days into the year from system & adds additional days in multiples of 7 depending on how many weeks the user wants to advance.  Helper search function.
    func getDaysIntoYear(nowPlusWeeks: Int) -> Int { //we don't have to worry about getting old events because old events are never read or put into FB
        var daysIntoYear:Int = 0
        let calendar = Calendar.current
        let date = Date()
        var daysInMonths:[Int] = [31, 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31]
        if calendar.component(.year, from: date) % 4 == 0 { //check if leap year
            daysInMonths[1] = 29
        }
        let currentMonth = calendar.component(.month, from: date)
        let currentDay = calendar.component(.day, from: date)
        var i:Int = 1
        while i < currentMonth {
            daysIntoYear += daysInMonths[i-1]
            i += 1
        }
        daysIntoYear += currentDay
        return daysIntoYear + nowPlusWeeks*7
    }
    
    //Tomohiko Sakamoto algorithm
    static func getDayOfWeek(day: Int, month: Int, year: Int) -> Int {
        var y = year;
        let t:[Int] = [0, 3, 2, 5, 0, 3, 5, 1, 4, 6, 2, 4]
        y -= month < 3 ? 1 : 0
        var x:Int = y + y/4
        x -= y/100
        x += y/400
        x += t[month-1] + day
        x %= 7
        return x
    }
    
    func isVirtual(event: EventInstance) {
        if event.mainLon == 0.0 && event.mainLat == 0.0 && (event.location.lowercased() == "virtual" || event.location == "") {
            event.isVirtual = true
        }
    }
    
    func checkIsVirtual(event: EventInstance) -> Bool {
        if event.mainLon == 0.0 && event.mainLat == 0.0 && (event.location.lowercased() == "virtual" || event.location == "") {
            return true
        }
        return false
    }
    
    //determine if any events are favorited
    func doFavoritesExist(list: [EventInstance]) -> Bool {
        for event in list {
            if event.isFavorite {
                return true
            }
        }
        return false
    }
    
    func sanitizeCoords(event: EventInstance) {
        if (event.mainLat < 0 && event.mainLon > 0) {
            let temp = event.mainLat
             event.mainLat = event.mainLon
             event.mainLon = temp
       }
    }
    
    func alert(title: String, message: String) -> Alert {
        return Alert(title: Text(title), message: Text(message), dismissButton: .default(Text("OK")))
    }
    
    func navAlert(lat: Double, lon: Double) -> Alert {
        return Alert(title: Text("Too Far to Navigate to Event in StetsonScene"), message: Text("You're currently too far away from campus to navigate to this event through StetsonScene; would you like to navigate to it with Apple Maps?"),
              primaryButton: .default(Text("Navigate in Apple Maps")) {
                let url = URL(string: "http://maps.apple.com/maps?saddr=&daddr=\(lat),\(lon)")
                UIApplication.shared.open(url!)
              }, secondaryButton: .cancel())
    }
    
        func getEventDate(event: EventInstance) -> Date {
            //var event: EventInstance = event
            var stringDate: String = event.date ?? "1/1/0001"

            //if date has a single digit month, prepare it for dateFormat by adding a second month digit
            if stringDate.count != 10 {
                stringDate = "0" + stringDate
            }

            let dateFormatter = DateFormatter()
            dateFormatter.locale = Locale(identifier: "en_US_POSIX") // set locale to reliable US_POSIX
            dateFormatter.dateFormat = "MM/dd/yyyy"
            let date = dateFormatter.date(from: stringDate)!

            let calendar = Calendar.current
            let components = calendar.dateComponents([.year, .month, .day, .weekday], from: date)

    //        event.date = calendar.date(from:components)! //full thing
    //        event.month = String(calendar.component(.month, from: date)) //TODO: get the actual month, not just a number
    //        event.day = String(calendar.component(.day, from: date))
    //        event.weekday = String(calendar.component(.weekday, from: date)) //TODO: get the actual weekday, not just a number

            return calendar.date(from:components)!
        }
    
    //MARK: FOR SHARING
    //scrapes html for links
    func makeLink(text: String) -> String {
        //print("AIUGKSBAKJBKBFEKB")
        let linkPattern = #"(<a href=")(.)+?(?=")"#
        do {
            let linkRegex = try NSRegularExpression(pattern: linkPattern, options: [])
            if linkRegex.firstMatch(in: text, options: [], range: NSRange(text.startIndex..., in: text)) != nil {
                //print("matched")
                let linkCG = linkRegex.firstMatch(in: text, options: [], range: NSRange(text.startIndex..., in: text))
                let range = linkCG?.range(at: 0)
                var link:String = (text as NSString).substring(with: range!)
                let scrapeHTMLPattern = #"(<a href=")"#
                let scrapeHTMLRegex = try NSRegularExpression(pattern: scrapeHTMLPattern, options: [])
                link = scrapeHTMLRegex.stringByReplacingMatches(in: link, options: [], range: NSRange(link.startIndex..., in: link), withTemplate: "")
                //print(link)
                if !link.contains("http") && !link.contains("https") { return "" } else { return link }
            }
        } catch { print("Regex error") }
        return ""
    }
    
    //Function removes carryover HTML tags & elements from the event descriptions
    func scrapeHTMLTags(text: String) -> String {
        let scrapeHTMLPattern = #"<[^>]+>"#
        let nbspPattern = #"&\w+;"#
        let paragraphPattern = #"</p>"#
        do {
            let scrapeHTMLRegex = try NSRegularExpression(pattern: scrapeHTMLPattern, options: [])
            let nbspRegex = try NSRegularExpression(pattern: nbspPattern, options: [])
            let paragraphRegex = try NSRegularExpression(pattern: paragraphPattern, options: [])
            var scrapedString = paragraphRegex.stringByReplacingMatches(in: text, options: [], range: NSRange(text.startIndex..., in: text), withTemplate: "\n")
            scrapedString = scrapeHTMLRegex.stringByReplacingMatches(in: scrapedString, options: [], range: NSRange(text.startIndex..., in: scrapedString), withTemplate: "")
            scrapedString = nbspRegex.stringByReplacingMatches(in: scrapedString, options: [], range: NSRange(scrapedString.startIndex..., in: scrapedString), withTemplate: " ")
            return scrapedString
        } catch { print("Regex error") }
        return text
    }
    
    func compareDates(date1: Date, date2: Date) -> Bool {
        let dateFormatter = DateFormatter()
        dateFormatter.dateStyle = .short
        if dateFormatter.string(from: date1) == dateFormatter.string(from: date2) {
            return true
        } else {
            return false
        }
    }
}

enum AM_PM: Int {
    case am = 1
    case pm = 2
}

struct DateTimeInfo {
    let year:Int
    let month:Int
    let day:Int
    let hour:Int
    let minute:Int
    let am_pm:AM_PM
    
    //Returns true if first date/time is later than second date, false if else
    static func >(dateTimeOne: DateTimeInfo, dateTimeTwo: DateTimeInfo) -> Bool {
        if dateTimeOne.year > dateTimeTwo.year { return true } else if dateTimeOne.year < dateTimeTwo.year { return false }
        if dateTimeOne.month > dateTimeTwo.month { return true } else if dateTimeOne.month < dateTimeTwo.month { return false }
        if dateTimeOne.day > dateTimeTwo.day { return true } else if dateTimeOne.day < dateTimeTwo.day { return false }
        if dateTimeOne.am_pm.rawValue > dateTimeTwo.am_pm.rawValue { return true } else if dateTimeOne.am_pm.rawValue < dateTimeTwo.am_pm.rawValue { return false }
        if dateTimeOne.hour > dateTimeTwo.hour { return true } else if dateTimeOne.hour < dateTimeTwo.hour { return false }
        if dateTimeOne.minute > dateTimeTwo.minute { return true } else if dateTimeOne.minute < dateTimeTwo.minute { return false }
        return false
    }
    
    static func ==(dateTimeOne: DateTimeInfo, dateTimeTwo: DateTimeInfo) -> Bool {
        if (dateTimeOne.year == dateTimeTwo.year) && (dateTimeOne.month == dateTimeTwo.month) && (dateTimeOne.day == dateTimeTwo.day) {
            return true
        }
        return false
    }
}

enum MyError: Error {
   case conversionError
}

func getInt(_ data: String) throws -> Int {
    guard let result = Int(data) else { throw MyError.conversionError }
    return result

}

func haptic() {
    //print("activated haptic")
    let generator = UINotificationFeedbackGenerator()
    generator.notificationOccurred(.success)
}

//
//  ListView.swift
//  StetsonScene
//
//  Created by Madison Gipson on 7/15/20.
//  Copyright © 2020 Madison Gipson. All rights reserved.
//

import Foundation
import SwiftUI
import CoreLocation

func print5(_ str: String) {
    for _ in 0..<5 {
        print("did thing " + str)
    }
}

struct ListView : View {
    @ObservedObject var evm:EventViewModel
    @EnvironmentObject var config: Configuration
    @Environment(\.colorScheme) var colorScheme
    var eventLocation: String? = ""
    var allVirtual: Bool? = false
    
    @Binding var page:String
    @Binding var subPage:String
    //ListView(evm: self.evm, eventLocation: event.location!, page: self.$page, subPage: self.$subPage)
    
    func returnCorrectList() -> some View {
        if (self.subPage == "AR" || self.subPage == "Map") {
            print5("mapar")
            return AnyView(List {
                ForEach(self.evm.eventList) { event in
                    if (self.page == "Favorites" && event.isFavorite) || self.page == "Discover" { //if favorites screen, only favorites... otherwise any
                        if (event.isVirtual && self.allVirtual!) || (event.location! == self.eventLocation!) { //listing only virtual events OR navigating to a specific event
                            ListCell(evm: self.evm, event: event, page: self.$page, subPage: self.$subPage)
                        }
                    }
                }.listRowBackground((self.page == "Favorites" && colorScheme == .light) ? config.accent : Color.secondarySystemBackground)
            }.background((self.page == "Favorites" && colorScheme == .light) ? config.accent : Color.secondarySystemBackground))
        }
        if (self.subPage == "List" || self.subPage == "Calendar") { //just to clarify
        if self.page == "Favorites" {
            print5("fav")
            return AnyView(List {
                ForEach(self.evm.eventList) { event in
                    if event.isFavorite {
                        ListCell(evm: self.evm, event: event, page: self.$page, subPage: self.$subPage)
                    }
                }.listRowBackground((self.page == "Favorites" && colorScheme == .light) ? config.accent : Color.secondarySystemBackground)
            }.background((self.page == "Favorites" && colorScheme == .light) ? config.accent : Color.secondarySystemBackground))
        }
        if self.page == "Discover" {
            print5("discover")
            return AnyView(List {
                ForEach(self.evm.eventList) { event in
                    if event.filteredOn {
                        ListCell(evm: self.evm, event: event, page: self.$page, subPage: self.$subPage)
                    }
                }.listRowBackground((self.page == "Favorites" && colorScheme == .light) ? config.accent : Color.secondarySystemBackground)
            }.background((self.page == "Favorites" && colorScheme == .light) ? config.accent : Color.secondarySystemBackground))
        }
        }
        return AnyView(EmptyView())
    }
    
    var body: some View {
        returnCorrectList()
//        VStack(spacing: 0) {
////            //LIST
//            List {
//                ForEach(self.evm.eventList) { event in
////                    //have to do this by subpage then page to get the correct sub-lists
////                    //if (self.config.subPage == "AR" || self.config.subPage == "Map") {
////                        //if event.isVirtual && self.allVirtual == true { //listing only virtual events
//                            ListCell(evm: self.evm, event: event)
////                        //}
////                        //if event.location! == self.eventLocation! { //navigating to a specific event
////                          //  if self.config.page == "Discover" || (self.config.page == "Favorites" && event.isFavorite) {
////                            //    ListCell(evm: self.evm, event: event)
////                            //}
////                        //}
////                    //} //else if (self.config.subPage == "List") {//|| self.config.subPage == "Calendar") && event.filteredOn {
////                    //if (self.config.page == "Discover") {// && event.filteredOn) || (self.config.page == "Favorites" && event.isFavorite) {
////                      //      ListCell(evm: self.evm, event: event)
//                        //}
//                    //}
//                }.listRowBackground((config.page == "Favorites" && colorScheme == .light) ? config.accent : Color.secondarySystemBackground)
//            }.background((config.page == "Favorites" && colorScheme == .light) ? config.accent : Color.secondarySystemBackground)
//        }
    } //end of View
}

//CONTENTS OF EACH EVENT CELL
struct ListCell : View {
    @ObservedObject var evm:EventViewModel
    @EnvironmentObject var config: Configuration
    @Environment(\.colorScheme) var colorScheme
    var event: EventInstance
    @State var detailView: Bool = false
    @State var share: Bool = false
    @State var calendar: Bool = false
    @State var fav: Bool = false
    @State var navigate: Bool = false
    @State var arMode: Bool = true //false=mapMode
    //for alerts
    @State var internalAlert: Bool = false
    @State var externalAlert: Bool = false
    @State var tooFar: Bool = false
    @State var arrived: Bool = false
    @State var eventDetails: Bool = false
    @State var isVirtual: Bool = false
    
    @Binding var page:String
    @Binding var subPage:String
    
    var body: some View {
        ZStack {
            HStack {
                //Date & Time, Left Side
                VStack(alignment: .trailing) {
                    //TODO: CHANGE DATESTRING TO MONTH + DAY
                    Text(event.date).fontWeight(.medium).font(.system(size: self.subPage == "Calendar" ? 12 : 16)).foregroundColor(config.accent).padding(.vertical, self.subPage == "Calendar" ? 2 : 5)
                    Text(event.time).fontWeight(.medium).font(.system(size: self.subPage == "Calendar" ? 10 : 12)).foregroundColor(Color.secondaryLabel).padding(.bottom, self.subPage == "Calendar" ? 2 : 5)
                    //Duration?
                }.padding(.horizontal, 5)
                
                //Name & Location, Right Side
                VStack(alignment: .leading) {
                    Text(event.name).fontWeight(.medium).font(.system(size: self.subPage == "Calendar" ? 16 : 22)).lineLimit(1).foregroundColor(event.hasCultural ? config.accent :  Color.label).padding(.vertical, self.subPage == "Calendar" ? 2 : 5)
                    Text(event.location).fontWeight(.light).font(.system(size: self.subPage == "Calendar" ? 12 : 16)).foregroundColor(Color.secondaryLabel).padding(.bottom, self.subPage == "Calendar" ? 2 : 5)
                }
                
                Spacer() //fill out rest of cell
            }.padding(.vertical, self.subPage == "Calendar" ? 5 : 10).padding(.horizontal, self.subPage == "Calendar" ? 5 : 10) //padding within the cell, between words and borders
        }.background(RoundedRectangle(cornerRadius: 10).stroke(Color.clear).foregroundColor(Color.label).background(RoundedRectangle(cornerRadius: 10).foregroundColor(self.page == "Favorites" ? (colorScheme == .light ? Color.secondarySystemBackground : config.accent.opacity(0.1)) : Color.tertiarySystemBackground)))
            .padding(.top, (self.subPage == "AR" || self.subPage == "Map") ? 15 : 0)
            .onTapGesture {
                self.detailView = true
                self.event.linkText = self.evm.makeLink(text: self.event.eventDescription)
            }
            .contextMenu {
                //SHARE
                Button(action: {
                    haptic()
                    self.share.toggle()
                    self.evm.isVirtual(event: self.event)
                    if self.event.isVirtual {
                        self.event.linkText = self.evm.makeLink(text: self.event.eventDescription)
                        if self.event.linkText == "" { self.event.isVirtual = false }
                        self.event.shareDetails = "Check out this event I found via StetsonScene! \(self.event.name!) is happening on \(self.event.date!) at \(self.event.time!)!"
                    } else {
                        self.event.shareDetails = "Check out this event I found via StetsonScene! \(self.event.name!), on \(self.event.date!) at \(self.event.time!), is happening at the \(self.event.location!)!"
                    }
                }) {
                    Text("Share")
                    Image(systemName: "square.and.arrow.up")
                }
                //ADD TO CALENDAR
                Button(action: {
                    haptic()
                    self.calendar = true
                }) {
                    Text(self.event.isInCalendar ? "Already in Calendar" : "Add to Calendar")
                    Image(systemName: "calendar.badge.plus")
                }
                
                //FAVORITE
                Button(action: {
                    haptic()
                    self.evm.toggleFavorite(self.event)
                    //self.fav = self.event.isFavorite //this fixes the display
                }) {
                    Text(self.event.isFavorite ? "Unfavorite":"Favorite")
                    Image(systemName: self.event.isFavorite ? "heart.fill":"heart")
                }
                
                //NAVIGATE
                Button(action: {
                    haptic()
                    self.evm.isVirtual(event: self.event)
                    //if you're trying to navigate to an event and are too far from campus, alert user and don't go to map
                    let locationManager = CLLocationManager()
                    let StetsonUniversity = CLLocation(latitude: 29.0349780, longitude: -81.3026430)
                    if !self.event.isVirtual && locationManager.location != nil && (CLLocationManager.authorizationStatus() == .authorizedWhenInUse || CLLocationManager.authorizationStatus() == .authorizedAlways) && StetsonUniversity.distance(from: locationManager.location!) > 805 {
                        self.externalAlert = true
                        self.tooFar = true
                        self.navigate = false
                    } else if self.event.isVirtual { //if you're trying to navigate to a virtual event, alert user and don't go to map
                        //TODO: add in the capability to follow a link to register or something
                        self.externalAlert = true
                        self.isVirtual = true
                        self.navigate = false
                    } else { //otherwise go to map
                        self.externalAlert = false
                        self.isVirtual = false
                        self.tooFar = false
                        self.navigate = true
                    }
                }) {
                    Text("Navigate")
                    Image(systemName: "location")
                }
        } //end of context menu
            .background(EmptyView().sheet(isPresented: $detailView, content: { //notice that these backgrounds are nested- weird but it works
                EventDetailView(evm: self.evm, event: self.event, page: self.$page, subPage: self.$subPage).environmentObject(self.config)
            }).background(EmptyView().sheet(isPresented: $navigate, content: {
                ZStack {
                    if self.arMode && !self.event.isVirtual {
                        ARNavigationIndicator(evm: self.evm, arFindMode: false, navToEvent: self.event, internalAlert: self.$internalAlert, externalAlert: self.$externalAlert, tooFar: .constant(false), allVirtual: .constant(false), arrived: self.$arrived, eventDetails: self.$eventDetails, page: self.$page, subPage: self.$subPage).environmentObject(self.config)
                    } else if !self.event.isVirtual { //mapMode
                        MapView(evm: self.evm, mapFindMode: false, navToEvent: self.event, internalAlert: self.$internalAlert, externalAlert: self.$externalAlert, tooFar: .constant(false), allVirtual: .constant(false), arrived: self.$arrived, eventDetails: self.$eventDetails, page: self.$page, subPage: self.$subPage).environmentObject(self.config)
                    }
                    if self.config.appEventMode {
                        ZStack {
                            Text(self.arMode ? "Map View" : "AR View").fontWeight(.light).font(.system(size: 18)).foregroundColor(self.config.accent)
                        }.padding(10)
                            .background(RoundedRectangle(cornerRadius: 15).stroke(Color.clear).foregroundColor(Color.tertiarySystemBackground.opacity(0.8)).background(RoundedRectangle(cornerRadius: 10).foregroundColor(Color.tertiarySystemBackground.opacity(0.8))))
                            .onTapGesture { withAnimation { self.arMode.toggle() } }
                            .offset(y: Constants.height*0.4)
                    }
                }.alert(isPresented: self.$internalAlert) { () -> Alert in //done in the view
                    if self.arrived {
                        return self.evm.alert(title: "You've Arrived!", message: "Have fun at \(String(describing: self.event.name!))!")
                    } else if self.eventDetails {
                        return self.evm.alert(title: "\(self.event.name!)", message: "This event is at \(self.event.time!) on \(self.event.date!).")/*, and you are \(distanceFromBuilding!)m from \(event!.location!)*/
                    }
                    return self.evm.alert(title: "ERROR", message: "Please report as a bug.")
                }
            }).alert(isPresented: self.$externalAlert) { () -> Alert in //done outside the view
                if self.isVirtual {
                    return self.evm.alert(title: "Virtual Event", message: "Sorry! This event is virtual, so you have no where to navigate to.")
                } else if self.tooFar {
                    //return self.evm.alert(title: "Too Far to Navigate to Event", message: "You're currently too far away from campus to navigate to this event. You can still view it in the map, and once you get closer to campus, can navigate there.")
                    return self.evm.navAlert(lat: self.event.mainLat, lon: self.event.mainLon)
                }
                return self.evm.alert(title: "ERROR", message: "Please report as a bug.")
            }.background(EmptyView().sheet(isPresented: $share, content: { //NEED TO LINK TO APPROPRIATE LINKS ONCE APP IS PUBLISHED
                ShareView(activityItems: [(self.event.isVirtual && URL(string: self.event.linkText) != nil) ? URL(string: self.event.linkText)!:"", self.event.hasCultural ? "\(self.event.shareDetails) It’s even offering a cultural credit!" : "\(self.event.shareDetails)"/*, event.isVirtual ? URL(string: event.linkText)!:""*/], applicationActivities: nil)
            }))))
            .actionSheet(isPresented: $calendar) {
                self.evm.manageCalendar(self.event)
        } //end of background and action sheet nonsense
    }
}

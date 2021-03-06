//
//  FilterView.swift
//  StetsonScene
//
//  Created by Madison Gipson on 7/15/20.
//  Copyright © 2020 Madison Gipson. All rights reserved.
//

import Foundation
import SwiftUI

struct FilterView : View {
    @ObservedObject var evm:EventViewModel
    @EnvironmentObject var config: Configuration
    @Binding var filterView:Bool
    @Binding var filterApplied:Bool
    
    //Filter properties linked to search engine
    @State var weeksDisplayed:Double
    
//    @State var filterApplied:Bool {
//        didSet {
//            evm.eventSearchEngine.filterApplied = self.filterApplied
//        }
//    }
    @State var weekdaysSelected:[Bool] {
        didSet {
            evm.eventSearchEngine.weekdaysSelected = self.weekdaysSelected
        }
    }
    @State var onlyCultural:Bool {
        didSet {
            evm.eventSearchEngine.onlyCultural = self.onlyCultural
        }
    }
    @State var onlyVirtual:Bool {
           didSet {
               evm.eventSearchEngine.onlyVirtual = self.onlyVirtual
           }
       }
    
    
    @State var eventTypesSelected:Set<String> //Passed down to FilterEventTypeView
    
    func daysOfWeekView() -> some View {
        let systemImagesLetters:[String] = ["s.square", "m.square", "t.square", "w.square", "t.square", "f.square", "s.square"]
        return HStack {
            ForEach(0 ..< weekdaysSelected.count) { i in
                Button(action: {
                    self.weekdaysSelected[i].toggle()
                }) {
                    !self.weekdaysSelected[i] ? Image(systemName: systemImagesLetters[i]).foregroundColor(self.config.accent).scaleEffect(1.5).padding(.bottom).padding(.horizontal, Constants.width/28) : Image(systemName: systemImagesLetters[i] + ".fill").foregroundColor(self.config.accent).scaleEffect(1.5).padding(.bottom).padding(.horizontal, Constants.width/28)
                }
            }
        }
    }
    
    var body: some View {
        VStack {
            CustomSlider(value: $weeksDisplayed, range: (1, 20)) { modifiers in
              ZStack {
                LinearGradient(gradient: .init(colors: [self.config.accent.opacity(0.25), self.config.accent]), startPoint: .leading, endPoint: .trailing)
                Text("Number of Weeks Displayed").font(.system(size: 16, weight: .light, design: .default)).foregroundColor(Color.white)
                ZStack {
                    Circle().fill(Color.black)
                    Text(("\(Int(self.weeksDisplayed))")).font(.system(size: 14, weight: .heavy, design: .default)).foregroundColor(Color.white)
                }
                .padding([.top, .bottom], 2)
                .modifier(modifiers.knob)
              }.cornerRadius(15)
            }.frame(height: 30).padding([.top, .bottom])
            daysOfWeekView()
            Divider().background(config.accent)
            Button(action: { //If checked only events that have cultural credits should be presented after filtering
                self.onlyCultural.toggle()
            }) {
                HStack {
                    Text("Cultural Credits Only").foregroundColor(self.config.accent).padding()
                    Spacer()
                    ZStack {
                        Image(systemName: "square").foregroundColor(Color.secondarySystemBackground).scaleEffect(1.5).padding()
                        if self.onlyCultural {
                            Image(systemName: "checkmark").foregroundColor(self.config.accent).padding()
                        }
                    }
                }
            }.foregroundColor(Color.white)
            Button(action: { //If checked only events that have cultural credits should be presented after filtering
                self.onlyVirtual.toggle()
            }) {
                HStack {
                    Text("Virtual Events Only").foregroundColor(self.config.accent).padding()
                    Spacer()
                    ZStack {
                        Image(systemName: "square").foregroundColor(Color.secondarySystemBackground).scaleEffect(1.5).padding()
                        if self.onlyVirtual {
                            Image(systemName: "checkmark").foregroundColor(self.config.accent).padding()
                        }
                    }
                }
            }.foregroundColor(Color.white)
            Divider().background(config.accent)
            //Select event type view
            FilterEventTypeView(evm: self.evm, selectAllDeselectAll: {
                if self.eventTypesSelected.count > self.evm.eventTypeList.count/2 {
                    return false
                }
                return true
            }(), eventTypesSelected: self.$eventTypesSelected).environmentObject(self.config)
            Spacer()
            Divider().background(config.accent)
            //Search Button
            Button("Search") { //Calls filter method of EventSearchEngine instance in primary ViewModel instance to interact with the event list and apply correct filter to all elements
                self.evm.eventSearchEngine.weeksDisplayed = Int(self.weeksDisplayed)
                self.filterView = false //Dismiss modal
                self.evm.eventSearchEngine.filter(evm: self.evm)
                //Update after filter in case filter needs to load more data we want to keep this accurate as to what is actually loaded
                self.evm.weeksStored = self.evm.eventSearchEngine.weeksDisplayed > self.evm.weeksStored ? self.evm.eventSearchEngine.weeksDisplayed : self.evm.weeksStored
                //show that filter is applied
                self.filterApplied = false //reset it- it will save
                for i in 0 ..< self.weekdaysSelected.count { //if one of the weekdays is NOT selected (e.g. not the default every day of the week)
                    if !self.weekdaysSelected[i] {
                        self.filterApplied = true
                    }
                }
                if self.onlyCultural || self.onlyVirtual { //if cultural or virtual filters are selected
                    self.filterApplied = true
                }
                //TODO: add something for the event types filter
                if self.evm.eventTypeList.count != self.evm.eventSearchEngine.eventTypeSet.count {
                    self.filterApplied = true
                }
                haptic()
            }.buttonStyle(MainButtonStyle(accentColor: config.accent)).padding(.horizontal, Constants.width*0.1)
        }.padding()
    }
}

// SLIDER VIEW STUFF //

struct CustomSliderComponents {
    let barLeft: CustomSliderModifier
    let barRight: CustomSliderModifier
    let knob: CustomSliderModifier
}

struct CustomSliderModifier: ViewModifier {
    enum Name {
        case barLeft
        case barRight
        case knob
    }
    let name: Name
    let size: CGSize
    let offset: CGFloat

    func body(content: Content) -> some View {
        content
        .frame(width: size.width)
        .position(x: size.width*0.5, y: size.height*0.5)
        .offset(x: offset)
    }
}

struct CustomSlider<Component: View>: View {
    
    @Binding var value: Double
    var range: (Double, Double)
    var knobWidth: CGFloat?
    let viewBuilder: (CustomSliderComponents) -> Component

    init(value: Binding<Double>, range: (Double, Double), knobWidth: CGFloat? = nil,
         _ viewBuilder: @escaping (CustomSliderComponents) -> Component
    ) {
        _value = value
        self.range = range
        self.viewBuilder = viewBuilder
        self.knobWidth = knobWidth
    }

    var body: some View {
        return GeometryReader { geometry in
            self.view(geometry: geometry)
        }
    }
    
    private func onDragChange(_ drag: DragGesture.Value,_ frame: CGRect) {
        //haptic()
        let width = (knob: Double(knobWidth ?? frame.size.height), view: Double(frame.size.width))
        let xrange = (min: Double(0), max: Double(width.view - width.knob))
        var value = Double(drag.startLocation.x + drag.translation.width) // knob center x
        value -= 0.5*width.knob // offset from center to leading edge of knob
        value = value > xrange.max ? xrange.max : value // limit to leading edge
        value = value < xrange.min ? xrange.min : value // limit to trailing edge
        value = value.convert(fromRange: (xrange.min, xrange.max), toRange: range)
        self.value = value
    }
    
    private func getOffsetX(frame: CGRect) -> CGFloat {
        let width = (knob: knobWidth ?? frame.size.height, view: frame.size.width)
        let xrange: (Double, Double) = (0, Double(width.view - width.knob))
        let result = self.value.convert(fromRange: range, toRange: xrange)
        return CGFloat(result)
    }
    
    private func view(geometry: GeometryProxy) -> some View {
      let frame = geometry.frame(in: .global)
      let drag = DragGesture(minimumDistance: 0).onChanged({ drag in
        self.onDragChange(drag, frame) }
      )
      let offsetX = self.getOffsetX(frame: frame)

      let knobSize = CGSize(width: knobWidth ?? frame.height, height: frame.height)
      let barLeftSize = CGSize(width: CGFloat(offsetX + knobSize.width * 0.5), height:  frame.height)
      let barRightSize = CGSize(width: frame.width - barLeftSize.width, height: frame.height)

      let modifiers = CustomSliderComponents(
          barLeft: CustomSliderModifier(name: .barLeft, size: barLeftSize, offset: 0),
          barRight: CustomSliderModifier(name: .barRight, size: barRightSize, offset: barLeftSize.width),
          knob: CustomSliderModifier(name: .knob, size: knobSize, offset: offsetX))

      return ZStack { viewBuilder(modifiers).gesture(drag) }
    }
}

extension Double {
    func convert(fromRange: (Double, Double), toRange: (Double, Double)) -> Double {
        // Example: if self = 1, fromRange = (0,2), toRange = (10,12) -> solution = 11
        var value = self
        value -= fromRange.0
        value /= Double(fromRange.1 - fromRange.0)
        value *= toRange.1 - toRange.0
        value += toRange.0
        return value
    }
}

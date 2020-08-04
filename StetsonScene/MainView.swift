//
//  MainView.swift
//  StetsonScene
//
//  Created by Madison Gipson on 2/5/20.
//  Copyright © 2020 Madison Gipson. All rights reserved.
//
import Foundation
import SwiftUI
import UIKit

struct ARNavigationIndicator: UIViewControllerRepresentable {
    typealias UIViewControllerType = ARView
    @EnvironmentObject var config: Configuration
    var arFindMode: Bool
    var navToEvent: EventInstance?
    @Binding var internalAlert: Bool
    @Binding var externalAlert: Bool
    @Binding var tooFar: Bool
    @Binding var allVirtual: Bool
    @Binding var arrived: Bool
    @Binding var eventDetails: Bool
    
    func makeUIViewController(context: Context) -> ARView {
        return ARView(config: self.config, arFindMode: self.arFindMode, navToEvent: self.navToEvent ?? EventInstance(), internalAlert: self.$internalAlert, externalAlert: self.$externalAlert, tooFar: self.$tooFar, allVirtual: self.$allVirtual, arrived: self.$arrived, eventDetails: self.$eventDetails)
    }
    func updateUIViewController(_ uiViewController: ARNavigationIndicator.UIViewControllerType, context: UIViewControllerRepresentableContext<ARNavigationIndicator>) { }
}

struct MainView : View {
    @EnvironmentObject var config: Configuration
    @Environment(\.colorScheme) var colorScheme
    @State var listVirtualEvents:Bool = false
    //for alerts
    @State var externalAlert: Bool = false
    @State var tooFar: Bool = false
    @State var allVirtual: Bool = false
    
    var body: some View {
        ZStack {
            Color((config.page == "Favorites" && colorScheme == .light) ? config.accentUIColor : UIColor.secondarySystemBackground).edgesIgnoringSafeArea(.all)
            VStack(spacing: 0) {
                if config.page == "Trending" {
                    TrendingView().disabled(config.showOptions ? true : false)
                } else if config.page == "Discover" || config.page == "Favorites" {
                    if config.subPage == "List" || config.subPage == "Calendar" {
                        DiscoverFavoritesView().blur(radius: config.showOptions ? 5 : 0).disabled(config.showOptions ? true : false)
                    } else { //AR or Map
                        ZStack {
                            if config.subPage == "AR" {
                                ARNavigationIndicator(arFindMode: true, internalAlert: .constant(false), externalAlert: self.$externalAlert, tooFar: self.$tooFar, allVirtual: self.$allVirtual, arrived: .constant(false), eventDetails: .constant(false)).environmentObject(self.config)
                                    .blur(radius: config.showOptions ? 5 : 0)
                                    .disabled(config.showOptions ? true : false)
                                    .edgesIgnoringSafeArea(.top)
                                    .alert(isPresented: self.$externalAlert) { () -> Alert in
                                        if self.tooFar {
                                            return self.config.eventViewModel.alert(title: "Too Far to Tour with AR", message: "You're currently too far away from campus to use the AR feature to tour. Try using the map instead.")
                                        } else if self.allVirtual {
                                            return self.config.eventViewModel.alert(title: "All Events are Virtual", message: "Unfortunately, there are no events on campus at the moment. Check out the virtual event list instead.")
                                        }
                                        return self.config.eventViewModel.alert(title: "ERROR", message: "Please report as a bug.")
                                     }
                            } else if config.subPage == "Map" {
                                MapView(mapFindMode: true, internalAlert: .constant(false), externalAlert: .constant(false), tooFar: .constant(false), allVirtual: self.$allVirtual, arrived: .constant(false), eventDetails: .constant(false)).environmentObject(self.config)
                                    .blur(radius: config.showOptions ? 5 : 0)
                                    .disabled(config.showOptions ? true : false)
                                    .edgesIgnoringSafeArea(.top)
                                    .alert(isPresented: self.$allVirtual) { () -> Alert in
                                        return self.config.eventViewModel.alert(title: "All Events are Virtual", message: "Unfortunately, there are no events on campus at the moment. Check out the virtual event list instead.")
                                    }
                            }
                            if config.appEventMode {
                                ZStack {
                                    Text("Virtual Events").fontWeight(.light).font(.system(size: 18)).foregroundColor(config.accent)
                                }.padding(10)
                                    .background(RoundedRectangle(cornerRadius: 15).stroke(Color.clear).foregroundColor(Color.tertiarySystemBackground.opacity(0.8)).background(RoundedRectangle(cornerRadius: 10).foregroundColor(Color.tertiarySystemBackground.opacity(0.8))))
                                    .onTapGesture { withAnimation { self.listVirtualEvents = true } }
                                    .offset(y: Constants.height*0.38)
                            }
                        }.sheet(isPresented: $listVirtualEvents, content: {
                            ListView(allVirtual: true).environmentObject(self.config).background(Color.secondarySystemBackground)
                        })
                    }
                } else if config.page == "Information" {
                    InformationView().blur(radius: config.showOptions ? 5 : 0).disabled(config.showOptions ? true : false)
                } 
                
                TabBar()
                
            }.edgesIgnoringSafeArea(.bottom)
            
        }.animation(.spring())
    }
}

struct TabBar : View {
    @EnvironmentObject var config: Configuration
    
    var body: some View {
        ZStack {
            HStack(spacing: 20){
                //Trending
                HStack {
                    Image(systemName: "hand.thumbsup").resizable().frame(width: 20, height: 20).foregroundColor(config.page == "Trending" ? Color.white : Color.secondaryLabel)
                    Text(config.page == "Trending" ? config.page : "").fontWeight(.light).font(.system(size: 14)).foregroundColor(Color.white)
                }.padding(15)
                    .background(config.page == "Trending" ? config.accent : Color.clear)
                    .clipShape(Capsule())
                    .onTapGesture {
                        self.config.page = "Trending"
                        self.config.showOptions = false
                }
                //Discover
                HStack {
                    Image(systemName: "magnifyingglass").resizable().frame(width: 20, height: 20).foregroundColor(config.page == "Discover" ? Color.white : Color.secondaryLabel)
                    Text(config.page == "Discover" ? config.page : "").fontWeight(.light).font(.system(size: 14)).foregroundColor(Color.white)
                }.padding(15)
                    .background(config.page == "Discover" ? config.accent : Color.clear)
                    .clipShape(Capsule())
                    .onTapGesture {
                        if self.config.page == "Discover" {
                            self.config.showOptions.toggle()
                        } else {
                            self.config.showOptions = true
                        }
                        self.config.page = "Discover"
                }
                //Favorites
                HStack {
                    Image(systemName: "heart").resizable().frame(width: 20, height: 20).foregroundColor(config.page == "Favorites" ? Color.white : Color.secondaryLabel)
                    Text(config.page == "Favorites" ? config.page : "").fontWeight(.light).font(.system(size: 14)).foregroundColor(Color.white)
                }.padding(15)
                    .background(config.page == "Favorites" ? config.accent : Color.clear)
                    .clipShape(Capsule())
                    .onTapGesture {
                        if self.config.page == "Favorites" {
                            self.config.showOptions.toggle()
                        } else {
                            self.config.showOptions = true
                        }
                        self.config.page = "Favorites"
                }
                //Info
                HStack {
                    Image(systemName: "info.circle").resizable().frame(width: 20, height: 20).foregroundColor(config.page == "Information" ? Color.white : Color.secondaryLabel)
                    Text(config.page == "Information" ? config.page : "").fontWeight(.light).font(.system(size: 14)).foregroundColor(Color.white)
                }.padding(15)
                    .background(config.page == "Information" ? config.accent : Color.clear)
                    .clipShape(Capsule())
                    .onTapGesture {
                        self.config.page = "Information"
                        self.config.showOptions = false
                }
            }.padding(.vertical, 10)
                .frame(width: Constants.width)
                .background(Color.tertiarySystemBackground)
                .animation(.default) //hstack end
            
            //other tabs
            if self.config.showOptions {
                TabOptions().offset(x: self.config.page == "Discover" ? -30 : 30, y: -60)
            }
            
        }//zstack end
    }
}

struct TabOptions: View {
    @EnvironmentObject var config: Configuration
    @Environment(\.colorScheme) var colorScheme
    
    var body: some View {
        HStack {
            //List
            ZStack {
                Circle()
                    .stroke(Color.clear)
                    .background(self.config.subPage == "List" ? selectedColor(element: "background") : nonselectedColor(element: "background"))
                    .clipShape(Circle())
                Image(systemName: "list.bullet")
                    .resizable().frame(width: 20, height: 20)
                    .foregroundColor(self.config.subPage == "List" ? selectedColor(element: "foreground") : nonselectedColor(element: "foreground"))
            }.frame(width: 50, height: 50)
                .offset(x: 10)
                .onTapGesture {
                    withAnimation {
                        self.config.subPage = "List"
                        self.config.showOptions = false
                    }
            }
            //Calendar
            ZStack {
                Circle()
                    .stroke(Color.clear)
                    .background(self.config.subPage == "Calendar" ? selectedColor(element: "background") : nonselectedColor(element: "background"))
                    .clipShape(Circle())
                Image(systemName: "calendar")
                    .resizable().frame(width: 20, height: 20)
                    .foregroundColor(self.config.subPage == "Calendar" ? selectedColor(element: "foreground") : nonselectedColor(element: "foreground"))
            }.frame(width: 50, height: 50)
                .offset(y: -30)
                .onTapGesture {
                    withAnimation {
                        self.config.subPage = "Calendar"
                        self.config.showOptions = false
                    }
            }
            //AR
            ZStack {
                Circle()
                    .stroke(Color.clear)
                    .background(self.config.subPage == "AR" ? selectedColor(element: "background") : nonselectedColor(element: "background"))
                    .clipShape(Circle())
                Image(systemName: "camera")
                    .resizable().frame(width: 22, height: 18)
                    .foregroundColor(self.config.subPage == "AR" ? selectedColor(element: "foreground") : nonselectedColor(element: "foreground"))
            }.frame(width: 50, height: 50)
                .offset(y: -30)
                .onTapGesture {
                    withAnimation {
                        self.config.subPage = "AR"
                        self.config.showOptions = false
                    }
            }
            //Map
            ZStack {
                Circle()
                    .stroke(Color.clear)
                    .background(self.config.subPage == "Map" ? selectedColor(element: "background") : nonselectedColor(element: "background"))
                    .clipShape(Circle())
                Image(systemName: "mappin.and.ellipse")
                    .resizable().frame(width: 20, height: 22)
                    .foregroundColor(self.config.subPage == "Map" ? selectedColor(element: "foreground") : nonselectedColor(element: "foreground"))
            }.frame(width: 50, height: 50)
                .offset(x: -10)
                .onTapGesture {
                    withAnimation {
                        self.config.subPage = "Map"
                        self.config.showOptions = false
                    }
            }
        }.transition(.scale) //hstack
    }
    
    func selectedColor(element: String) -> Color {
        if element == "background" {
            return config.accent
        }
        //if element == stroke or foreground
        if colorScheme == .light {
            return Color.tertiarySystemBackground
        } else if colorScheme == .dark {
            return Color.secondaryLabel
        }
        
        return config.accent //absolute default
    }
    
    func nonselectedColor(element: String) -> Color {
        if element == "stroke" || element == "foreground" {
            return config.accent
        } else if element == "background" {
            if colorScheme == .light {
                return Color.tertiarySystemBackground
            } else if colorScheme == .dark {
                return Color.secondaryLabel
            }
        }
        return config.accent //absolute default
    }
}


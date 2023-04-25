//
//  ContentView.swift
//  testCustomEntitlementsComputation
//
//  Created by Andrés Boedo on 4/20/23.
//

import SwiftUI
import RevenueCat_CustomEntitlementComputation

struct CustomerInfoStreamFires: Identifiable {
    let customerInfo: CustomerInfo
    let id = UUID()
    let date: Date
}

struct ContentView: View {

    @State private var streamTask: Task<Void, Never>?
    @State private var offerings: Offerings?
    @State private var customerInfoStreamFires: [CustomerInfoStreamFires] = []
    @State private var showingLogInAlert = false
    @State private var appUserID = Constants.defaultAppUserID
    @State private var showingExplanation = false


    var body: some View {
        VStack {
            Text("Custom Entitlements Computation App")
                .font(.largeTitle)
                .padding()

            Button(action: {
                showingExplanation.toggle()
            }) {
                VStack{
                    Text("This app uses RevenueCat under CustomEntitlementsComputation mode.")
                        .foregroundColor(.primary)
                    Text("Tap here for more details about this mode.")
                        .bold()
                        .padding()
                        .foregroundColor(.primary)
                }
            }

            HStack {
                Text("Current App User ID:")
                    .bold()
                Text(appUserID)
            }

            Button(action: {
                showingLogInAlert = true
            }) {
                Text("Login")
                    .font(.system(size: 20))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.blue)
                    .cornerRadius(20)
                    .padding()

            }

            Button("Purchase first offering") {
                Task<Void, Never> {
                    await purchaseFirstOffering()
                }
            }
            .font(.system(size: 20))
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding()
            .background(Color.blue)
            .cornerRadius(20)
            .padding()

            .task {
                Purchases.configureInCustomEntitlementsComputationMode(apiKey: Constants.apiKey,
                                                                       appUserID: appUserID)
                do {
                    self.offerings = try await Purchases.shared.offerings()
                    print("offerings: \(String(describing: offerings))")
                } catch {
                    print("FAILED TO GET OFFERINGS: \(error.localizedDescription)")

                }
            }

            NavigationView {
                List(customerInfoStreamFires) { customerInfoStreamFire in
                    NavigationLink(destination: CustomerInfoDetailsView(customerInfo: customerInfoStreamFire.customerInfo)) {

                        VStack (alignment: .leading) {
                            HStack {
                                Text("Fired at:")
                                    .bold()
                                Text("\(customerInfoStreamFire.date, formatter: dateFormatter)")
                            }
                            HStack {
                                Text("App User ID:")
                                    .bold()
                                Text(customerInfoStreamFire.customerInfo.originalAppUserId)
                            }
                        }
                    }
                }
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .principal) {
                        VStack {
                            Text("CustomerInfo stream values")
                                .font(.headline)
                                .foregroundColor(.primary)
                                .padding()
                            Text("List fills in below when new values arrive.")
                                .foregroundColor(.primary)
                        }
                    }
                }
                .task {
                    subscribeToCustomerInfoStream()
                }
            }
        }
        .sheet(isPresented: $showingLogInAlert) {
            CustomAlert(inputText: $appUserID, logIn: logIn)
        }
        .sheet(isPresented: $showingExplanation) {
            ExplanationView()
        }
    }

    func logIn(_ appUserID: String) {
        Purchases.shared.switchUser(to: appUserID)
    }

    func subscribeToCustomerInfoStream() {
        self.streamTask = Task<Void, Never> {
            for await customerInfo in Purchases.shared.customerInfoStream {
                print("got new customerInfo: \(customerInfo)")
                customerInfoStreamFires.append(CustomerInfoStreamFires(customerInfo: customerInfo, date: Date()))
            }
        }
    }

    func purchaseFirstOffering() async {
        guard let offerings = self.offerings,
              let offering = offerings.current,
              let package = offering.availablePackages.first else {
            print("no offerings, can't make a purchase")
            return
        }

        do {
            let customerInfo = try await Purchases.shared.purchase(package: package)
            print(customerInfo)
        } catch {
            print("FAILED TO PURCHASE: \(error.localizedDescription)")
        }

    }


    private let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .medium
        return formatter
    }()
}


struct CustomAlert: View {
    @Environment(\.dismiss) var dismiss
    @Binding var inputText: String

    let logIn: (String) -> Void

    var body: some View {
        VStack(spacing: 20) {
            Text("Log In with different user:")
                .font(.headline)

            TextField("Enter App User ID here", text: $inputText)
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .padding(.horizontal)

            HStack {
                Button("Cancel") {
                    dismiss()
                }
                .padding()
                .background(Color.red)
                .cornerRadius(10)
                .foregroundColor(.white)

                Button("Log In") {
                    logIn(inputText)
                    dismiss()
                }
                .padding()
                .background(Color.green)
                .cornerRadius(10)
                .foregroundColor(.white)
            }
        }
        .padding()
    }
}

struct ExplanationView: View {
    var body: some View {
        VStack {
            Text("Custom Entitlements Mode")
                .font(.largeTitle)
                .padding()

            Text("This mode is intended for apps that will do their own entitlement computation, " +
                 "separate from RevenueCat. ")
            .padding()
            Text("In this mode, RevenueCat will not generate " +
                 "anonymous user IDs, it will not refresh customerInfo cache automatically " +
                 "(only when a purchase goes through), and it will disallow the logOut methods.")
            .padding()
            Text("Use logIn to switch to a different App User ID if needed. The SDK should only be configured once" +
                 "the initial appUserID is known.")
            .padding()
            Text("Apps using this mode rely on webhooks to signal their backends to refresh " +
                 "entitlements with RevenueCat.")
            .padding()

            Spacer()
        }
        .padding()
    }
}

struct CustomerInfoDetailsView: View {
    let customerInfo: CustomerInfo

    var prettyJSON: String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = .prettyPrinted

        if let jsonData = try? encoder.encode(customerInfo),
           let jsonString = String(data: jsonData, encoding: .utf8) {
            return jsonString
        } else {
            return "Error: Unable to convert CustomerInfo to JSON."
        }
    }

    var body: some View {
        VStack(alignment: .leading) {
            ScrollView {
                Text(prettyJSON)
                    .padding()
                    .font(.system(.body, design: .monospaced))
            }

            Spacer()
        }
        .padding()
        .navigationTitle("Customer Info Details")
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
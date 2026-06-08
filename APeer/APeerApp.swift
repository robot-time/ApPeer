import SwiftUI
import GoogleMobileAds

// MARK: - Models
struct APIResponse: Codable {
    let success: Bool
    let data: [Student]
    let count: Int
}

struct Student: Identifiable, Codable {
    let name: String
    let className: String
    let grade: String
    let studioSession1: String
    let studioSession2: String
    let studioSession3: String
    
    var id: String { name + className + grade }
    
    enum CodingKeys: String, CodingKey {
        case name
        case className = "class"
        case grade
        case studioSession1 = "studio1"
        case studioSession2 = "studio2"
        case studioSession3 = "studio3"
    }
}

// MARK: - View Models
class StudentViewModel: ObservableObject {
    @Published var students: [Student] = []
    @Published var searchText: String = ""
    @Published var filterType: FilterType = .name
    @Published var isLoading: Bool = false
    @Published var errorMessage: String?
    
    // Updated hardcoded class and grade data
    let availableClasses = ["AA", "AB", "BA", "BB", "CA", "CB", "DA", "DB"]
    let availableGrades = ["7", "8", "9", "10", "11", "12"]
    
    // Updated list of actual studios
    let availableStudios = [
        "3D Printing Masters",
        "ABHS Athletics",
        "ABHS Basketball League",
        "ABHS Soccer League",
        "ABHS Volleyball League",
        "AI Futures",
        "AUSLAN",
        "Be Vocal",
        "Bike Care Basics",
        "Cardboard Innovations: Building beyond the box",
        "Checkmate Beginners",
        "Checkmate Advanced",
        "Cook and Capture",
        "Cooking Essentials",
        "Creative Dance",
        "Dungeons and Dragons",
        "Dungeons and Dragons Advanced",
        "European Handball",
        "Footloose",
        "Forensic Detective Agency",
        "French Next Level",
        "Game On",
        "Gastronomy",
        "Glass Fusion",
        "HIIT it Up!",
        "Hook, Line and Sinker",
        "Immerse Me: VR and 360 Projects",
        "Inside the Great Wall",
        "Japanese Next level",
        "Mangia Pasta",
        "Model United Nations",
        "Music Production",
        "Navigating the Numberverse",
        "Photography 101: How to use a DSLR Camera",
        "Pickle Ball",
        "Public Speaking",
        "Radio Botanic",
        "Resonance",
        "Run Forrest Run",
        "Seasonal Food - Summer",
        "Shake up Shakespeare",
        "Silversmithing",
        "Silversmithing (Next Level)",
        "Social Squad",
        "Southern Zones Netball",
        "Sticker Me",
        "Sublimation Station",
        "The Power of Picture Books",
        "Today's Headlines",
        "VEX Robotics",
        "When in Rome",
        "Where in the World?",
        "Wood Creations",
        "Wood Creations (Next Level)"
    ].sorted() // Keep the list alphabetically sorted
    
    enum FilterType {
        case name
        case className
        case grade
        case studio
    }
    
    var filteredStudents: [Student] {
        guard !searchText.trimmingCharacters(in: .whitespaces).isEmpty else { return students }
        
        let searchQuery = searchText.lowercased().trimmingCharacters(in: .whitespaces)
        
        switch filterType {
        case .name:
            return students.filter { $0.name.lowercased().contains(searchQuery) }
        case .className:
            return students.filter { $0.className.lowercased().contains(searchQuery) }
        case .grade:
            return students.filter { $0.grade.lowercased().contains(searchQuery) }
        case .studio:
            return students.filter { student in
                student.studioSession1.lowercased().contains(searchQuery) ||
                student.studioSession2.lowercased().contains(searchQuery) ||
                student.studioSession3.lowercased().contains(searchQuery)
            }
        }
    }
    
    var uniqueClasses: [String] {
        return availableClasses
    }
    
    var uniqueGrades: [String] {
        return availableGrades
    }
    
    // Helper function to get students by class and grade
    func students(inClass className: String, grade: String) -> [Student] {
        students.filter { $0.className == className && $0.grade == grade }
    }
    
    func fetchStudents() {
        isLoading = true
        errorMessage = nil
        
        let apiEndpoint = "https://classbackend.vercel.app/api/student"
        
        guard let url = URL(string: apiEndpoint) else {
            errorMessage = "Invalid API URL"
            isLoading = false
            return
        }
        
        URLSession.shared.dataTask(with: url) { [weak self] data, response, error in
            DispatchQueue.main.async {
                self?.isLoading = false
                
                if let error = error {
                    self?.errorMessage = "Network error: \(error.localizedDescription)"
                    return
                }
                
                guard let httpResponse = response as? HTTPURLResponse, (200...299).contains(httpResponse.statusCode) else {
                    self?.errorMessage = "Server error"
                    return
                }
                
                guard let data = data else {
                    self?.errorMessage = "No data received"
                    return
                }
                
                do {
                    let decoder = JSONDecoder()
                    let response = try decoder.decode(APIResponse.self, from: data)
                    self?.students = response.data
                } catch {
                    self?.errorMessage = "Data parsing error: \(error.localizedDescription)"
                }
            }
        }.resume()
    }
    
    func fetchMetadata() async throws {
        let apiEndpoint = "https://classbackend.vercel.app/api/metadata"
        guard let url = URL(string: apiEndpoint) else {
            throw URLError(.badURL)
        }
        
        let (data, _) = try await URLSession.shared.data(from: url)
        let response = try JSONDecoder().decode(MetadataResponse.self, from: data)
        
        DispatchQueue.main.async {
            // Update your view model properties
            // This will depend on how you want to handle the metadata
        }
    }
}

// MARK: - Views
struct ContentView: View {
    @StateObject private var viewModel = StudentViewModel()
    @EnvironmentObject var userSettings: UserSettings
    @State private var showingSettings = false
    
    var body: some View {
        NavigationView {
            VStack {
                if let user = userSettings.userAccount {
                    Text("Welcome, \(user.name)")
                        .font(.headline)
                        .padding()
                }
                filterControls
                studentList
            }
            .navigationTitle("Class List")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: {
                        showingSettings = true
                    }) {
                        Image(systemName: "gear")
                    }
                }
            }
            .sheet(isPresented: $showingSettings) {
                SettingsView(userSettings: userSettings)
            }
            .onAppear {
                viewModel.fetchStudents()
            }
            .refreshable {
                viewModel.fetchStudents()
            }
        }
        .withBannerAd()
    }
    
    private var filterControls: some View {
        VStack(spacing: 12) {
            Picker("Filter Type", selection: $viewModel.filterType) {
                Text("Name").tag(StudentViewModel.FilterType.name)
                Text("Class").tag(StudentViewModel.FilterType.className)
                Text("Grade").tag(StudentViewModel.FilterType.grade)
                Text("Studio").tag(StudentViewModel.FilterType.studio)
            }
            .pickerStyle(SegmentedPickerStyle())
            .padding(.horizontal)
            
            if viewModel.filterType == .studio {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 10) {
                        ForEach(viewModel.availableStudios, id: \.self) { studio in
                            // Session 1 Tile
                            let session1Students = viewModel.students.filter { $0.studioSession1 == studio }
                            if !session1Students.isEmpty {
                                NavigationLink(destination: StudioDetailView(
                                    studioName: studio,
                                    sessionNumber: "1",
                                    students: session1Students
                                )) {
                                    StudioTile(studio: studio, session: "1", studentCount: session1Students.count)
                                }
                                .buttonStyle(PlainButtonStyle())
                            }
                            
                            // Session 2 Tile
                            let session2Students = viewModel.students.filter { $0.studioSession2 == studio }
                            if !session2Students.isEmpty {
                                NavigationLink(destination: StudioDetailView(
                                    studioName: studio,
                                    sessionNumber: "2",
                                    students: session2Students
                                )) {
                                    StudioTile(studio: studio, session: "2", studentCount: session2Students.count)
                                }
                                .buttonStyle(PlainButtonStyle())
                            }
                            
                            // Session 3 Tile
                            let session3Students = viewModel.students.filter { $0.studioSession3 == studio }
                            if !session3Students.isEmpty {
                                NavigationLink(destination: StudioDetailView(
                                    studioName: studio,
                                    sessionNumber: "3",
                                    students: session3Students
                                )) {
                                    StudioTile(studio: studio, session: "3", studentCount: session3Students.count)
                                }
                                .buttonStyle(PlainButtonStyle())
                            }
                        }
                    }
                    .padding(.horizontal)
                }
            } else {
                TextField("Search...", text: $viewModel.searchText)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .padding(.horizontal)
                    .autocapitalization(.none)
                    .disableAutocorrection(true)
            }
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(viewModel.uniqueGrades, id: \.self) { grade in
                        ForEach(viewModel.uniqueClasses, id: \.self) { className in
                            let studentsInClass = viewModel.students(inClass: className, grade: grade)
                            if !studentsInClass.isEmpty {
                                NavigationLink(destination: ClassDetailView(
                                    className: className,
                                    grade: grade,
                                    students: studentsInClass
                                )) {
                                    VStack {
                                        Text("Grade \(grade) - \(className)")
                                            .font(.headline)
                                        Text("\(studentsInClass.count) students")
                                            .font(.subheadline)
                                    }
                                    .padding()
                                    .background(Color.blue.opacity(0.1))
                                    .cornerRadius(8)
                                }
                                .buttonStyle(PlainButtonStyle())
                            }
                        }
                    }
                }
                .padding(.horizontal)
            }
        }
        .padding(.vertical)
    }
    
    private var studentList: some View {
        Group {
            if viewModel.isLoading {
                ProgressView("Loading students...")
            } else if let error = viewModel.errorMessage {
                ErrorView(message: error, retryAction: viewModel.fetchStudents)
            } else if viewModel.filteredStudents.isEmpty {
                EmptyStateView(isSearching: !viewModel.searchText.isEmpty)
            } else {
                List(viewModel.filteredStudents) { student in
                    StudentRow(student: student)
                }
            }
        }
    }
}

struct StudentRow: View {
    let student: Student
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(student.name)
                .font(.headline)
            
            Text("Class: \(student.className)")
                .font(.subheadline)
                .foregroundColor(.secondary)
            
            Text("Grade: \(student.grade)")
                .font(.subheadline)
                .foregroundColor(.secondary)
            
            Group {
                Text("Studio 1: \(student.studioSession1)")
                Text("Studio 2: \(student.studioSession2)")
                Text("Studio 3: \(student.studioSession3)")
            }
            .font(.subheadline)
            .foregroundColor(.secondary)
        }
        .padding(.vertical, 8)
    }
}

struct EmptyStateView: View {
    let isSearching: Bool
    
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 48))
                .foregroundColor(.secondary)
            
            Text(isSearching ? "No matching students found" : "No students available")
                .font(.headline)
                .foregroundColor(.secondary)
        }
    }
}

struct ErrorView: View {
    let message: String
    let retryAction: () -> Void
    
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 48))
                .foregroundColor(.red)
            
            Text(message)
                .font(.headline)
                .foregroundColor(.red)
                .multilineTextAlignment(.center)
            
            Button("Retry", action: retryAction)
                .buttonStyle(.bordered)
        }
        .padding()
    }
}

// Add a new view for displaying students in a specific class/grade
struct ClassDetailView: View {
    let className: String
    let grade: String
    let students: [Student]
    
    var body: some View {
        List(students) { student in
            StudentRow(student: student)
        }
        .navigationTitle("Grade \(grade) - \(className)")
    }
}

// Add UserDefaults keys and User model
struct UserAccount: Codable {
    let name: String
    let email: String
    let className: String
    let grade: String
    let studioSession1: String
    let studioSession2: String
    let studioSession3: String
}

class UserSettings: ObservableObject {
    @Published var isOnboarded: Bool {
        didSet {
            UserDefaults.standard.set(isOnboarded, forKey: "isOnboarded")
        }
    }
    
    @Published var userAccount: UserAccount? {
        didSet {
            if let encoded = try? JSONEncoder().encode(userAccount) {
                UserDefaults.standard.set(encoded, forKey: "userAccount")
            }
        }
    }
    
    init() {
        self.isOnboarded = UserDefaults.standard.bool(forKey: "isOnboarded")
        if let userData = UserDefaults.standard.data(forKey: "userAccount"),
           let decoded = try? JSONDecoder().decode(UserAccount.self, from: userData) {
            self.userAccount = decoded
        } else {
            self.userAccount = nil
        }
    }
    
    func verifyUser(name: String, className: String, grade: String) async throws -> Bool {
        let apiEndpoint = "https://classbackend.vercel.app/api/user/verify"
        guard let url = URL(string: apiEndpoint) else {
            throw URLError(.badURL)
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let userData = ["name": name, "className": className, "grade": grade]
        request.httpBody = try JSONEncoder().encode(userData)
        
        let (data, _) = try await URLSession.shared.data(for: request)
        let response = try JSONDecoder().decode(VerificationResponse.self, from: data)
        
        return response.verified
    }
    
    private let baseURL = "https://classbackend.vercel.app"
    
    func submitUserData(name: String, email: String, className: String, grade: String,
                       studioSession1: String, studioSession2: String, studioSession3: String) async throws {
        print("\n=== Starting New Submission ===")
        print("Raw input values:")
        print("Name: '\(name)'")
        print("Email: '\(email)'")
        print("Class: '\(className)'")
        print("Grade: '\(grade)'")
        print("Studio1: '\(studioSession1)'")
        print("Studio2: '\(studioSession2)'")
        print("Studio3: '\(studioSession3)'")
        
        guard let url = URL(string: "\(baseURL)/api/submit") else {
            throw URLError(.badURL)
        }
        
        // Match the exact format required by the API
        let requestBody: [String: String] = [
            "name": name.trimmingCharacters(in: .whitespaces),
            "email": email.trimmingCharacters(in: .whitespaces),
            "className": className,
            "grade": grade,
            "studio1": studioSession1,
            "studio2": studioSession2,
            "studio3": studioSession3
        ]
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let jsonData = try JSONSerialization.data(withJSONObject: requestBody, options: [])
        request.httpBody = jsonData
        
        print("\nRequest body:")
        if let jsonString = String(data: jsonData, encoding: .utf8) {
            print(jsonString)
        }
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw URLError(.badServerResponse)
        }
        
        print("\nResponse received:")
        print("Status code: \(httpResponse.statusCode)")
        if let responseString = String(data: data, encoding: .utf8) {
            print("Response body: \(responseString)")
        }
        
        // Handle 400 errors
        if httpResponse.statusCode == 400 {
            let errorResponse = try JSONDecoder().decode(ErrorResponse.self, from: data)
            throw NSError(
                domain: "APIError",
                code: 400,
                userInfo: [
                    NSLocalizedDescriptionKey: errorResponse.error,
                    "details": errorResponse.details ?? ""
                ]
            )
        }
        
        // For successful responses
        if (200...299).contains(httpResponse.statusCode) {
            let result = try JSONDecoder().decode(SubmissionResponse.self, from: data)
            if result.success {
                DispatchQueue.main.async {
                    self.userAccount = UserAccount(
                        name: name,
                        email: email,
                        className: className,
                        grade: grade,
                        studioSession1: studioSession1,
                        studioSession2: studioSession2,
                        studioSession3: studioSession3
                    )
                    self.isOnboarded = true
                }
                return // Success case
            }
        }
        
        // If we get here, something went wrong
        throw NSError(
            domain: "APIError",
            code: -1,
            userInfo: [NSLocalizedDescriptionKey: "Failed to submit data"]
        )
    }
}

struct VerificationResponse: Codable {
    let success: Bool
    let verified: Bool
    let message: String
}

struct MetadataResponse: Codable {
    let success: Bool
    let data: Metadata
}

struct Metadata: Codable {
    let classes: [String]
    let grades: [String]
}

struct SubmissionData: Codable {
    let name: String
    let email: String
    let className: String
    let grade: String
    let studioSession1: String
    let studioSession2: String
    let studioSession3: String
    
    enum CodingKeys: String, CodingKey {
        case name
        case email
        case className = "class"
        case grade
        case studioSession1 = "studio1"
        case studioSession2 = "studio2"
        case studioSession3 = "studio3"
    }
}

// Update the SubmissionResponse struct to match the exact API response
struct SubmissionResponse: Codable {
    let success: Bool
    let message: String
    let details: SubmissionDetails?
}

struct SubmissionDetails: Codable {
    let spreadsheetId: String
    let tableRange: String
    let updates: UpdateDetails
}

struct UpdateDetails: Codable {
    let spreadsheetId: String
    let updatedRange: String
    let updatedRows: Int
    let updatedColumns: Int
    let updatedCells: Int
}

// Add FirstLaunchManager to handle the popup
class FirstLaunchManager: ObservableObject {
    @Published var showUpdatePopup: Bool
    
    init() {
        self.showUpdatePopup = !UserDefaults.standard.bool(forKey: "hasSeenUpdatePopup")
    }
    
    func markPopupAsSeen() {
        UserDefaults.standard.set(true, forKey: "hasSeenUpdatePopup")
        showUpdatePopup = false
    }
}

// Update OnboardingView to include credits and popup
struct OnboardingView: View {
    @StateObject private var viewModel = StudentViewModel()
    @StateObject private var firstLaunchManager = FirstLaunchManager()
    @ObservedObject var userSettings: UserSettings
    @State private var name = ""
    @State private var email = ""
    @State private var selectedClass = "AA"
    @State private var selectedGrade = "7"
    @State private var studioSession1 = ""
    @State private var studioSession2 = ""
    @State private var studioSession3 = ""
    @State private var currentStep = 0
    @State private var showError = false
    @State private var errorMessage = ""
    
    var body: some View {
        VStack(spacing: 20) {
            Spacer()
            
            switch currentStep {
            case 0:
                creditsStep
            case 1:
                welcomeStep
            case 2:
                nameStep
            case 3:
                emailStep
            case 4:
                classStep
            case 5:
                gradeStep
            case 6:
                studioSession1Step
            case 7:
                studioSession2Step
            case 8:
                studioSession3Step
            default:
                EmptyView()
            }
            
            Spacer()
            
            navigationButtons
        }
        .padding()
        .alert("Review Update Coming Soon!", isPresented: $firstLaunchManager.showUpdatePopup) {
            Button("OK") {
                firstLaunchManager.markPopupAsSeen()
            }
        } message: {
            Text("We're excited to announce that a new review feature will be coming soon! Stay tuned for updates. As well as support for other classes (e.g. STEM, Global, etc.).")
        }
        .alert("Error", isPresented: $showError) {
            Button("OK") { }
        } message: {
            Text(errorMessage)
        }
        .onAppear {
            print("OnboardingView appeared")
            // Set initial values
            selectedClass = viewModel.availableClasses[0]
            selectedGrade = viewModel.availableGrades[0]
            // Set initial studio values and print for debugging
            if let firstStudio = viewModel.availableStudios.first {
                print("Setting initial studio: \(firstStudio)")
                studioSession1 = firstStudio
                studioSession2 = firstStudio
                studioSession3 = firstStudio
            } else {
                print("No studios available!")
            }
            
            // Print all available studios
            print("Available studios: \(viewModel.availableStudios)")
        }
    }
    
    private var welcomeStep: some View {
        VStack(spacing: 20) {
            Image(systemName: "person.crop.circle.badge.plus")
                .font(.system(size: 80))
                .foregroundColor(.blue)
            
            Text("Welcome to Student Class App!")
                .font(.title)
                .multilineTextAlignment(.center)
            
            Text("Let's set up your account")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
    }
    
    private var nameStep: some View {
        VStack(spacing: 20) {
            Text("What's your name?")
                .font(.title2)
            
            TextField("Enter your name", text: $name)
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .padding(.horizontal)
        }
    }
    
    private var emailStep: some View {
        VStack(spacing: 20) {
            Text("What's your email?")
                .font(.title2)
            
            TextField("Enter your email", text: $email)
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .keyboardType(.emailAddress)
                .autocapitalization(.none)
                .padding(.horizontal)
        }
    }
    
    private var classStep: some View {
        VStack(spacing: 20) {
            Text("Select your class")
                .font(.title2)
            
            if viewModel.uniqueClasses.isEmpty {
                Text("Loading classes...")
            } else {
                Picker("Class", selection: $selectedClass) {
                    ForEach(viewModel.uniqueClasses, id: \.self) { className in
                        Text(className).tag(className)
                    }
                }
                .pickerStyle(WheelPickerStyle())
                .onChange(of: selectedClass) { newValue in
                    print("Selected class changed to: \(newValue)")
                }
            }
        }
    }
    
    private var gradeStep: some View {
        VStack(spacing: 20) {
            Text("Select your grade")
                .font(.title2)
            
            if viewModel.uniqueGrades.isEmpty {
                Text("Loading grades...")
            } else {
                Picker("Grade", selection: $selectedGrade) {
                    ForEach(viewModel.uniqueGrades, id: \.self) { grade in
                        Text("Grade \(grade)").tag(grade)
                    }
                }
                .pickerStyle(WheelPickerStyle())
                .onChange(of: selectedGrade) { newValue in
                    print("Selected grade changed to: \(newValue)")
                }
            }
        }
    }
    
    private var studioSession1Step: some View {
        VStack(spacing: 20) {
            Text("What studio do you have in Session 1?")
                .font(.title2)
                .multilineTextAlignment(.center)
            
            if viewModel.availableStudios.isEmpty {
                Text("Loading studios...")
            } else {
                Picker("Session 1 Studio", selection: $studioSession1) {
                    ForEach(viewModel.availableStudios, id: \.self) { studio in
                        Text(studio)
                            .tag(studio)
                            .lineLimit(2)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                .pickerStyle(WheelPickerStyle())
            }
        }
        .onChange(of: studioSession1) { newValue in
            print("Studio 1 selected: \(newValue)")
        }
    }
    
    private var studioSession2Step: some View {
        VStack(spacing: 20) {
            Text("What studio do you have in Session 2?")
                .font(.title2)
                .multilineTextAlignment(.center)
            
            if viewModel.availableStudios.isEmpty {
                Text("Loading studios...")
            } else {
                Picker("Session 2 Studio", selection: $studioSession2) {
                    ForEach(viewModel.availableStudios, id: \.self) { studio in
                        Text(studio)
                            .tag(studio)
                            .lineLimit(2)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                .pickerStyle(WheelPickerStyle())
            }
        }
        .onChange(of: studioSession2) { newValue in
            print("Studio 2 selected: \(newValue)")
        }
    }
    
    private var studioSession3Step: some View {
        VStack(spacing: 20) {
            Text("What studio do you have in Session 3?")
                .font(.title2)
                .multilineTextAlignment(.center)
            
            if viewModel.availableStudios.isEmpty {
                Text("Loading studios...")
            } else {
                Picker("Session 3 Studio", selection: $studioSession3) {
                    ForEach(viewModel.availableStudios, id: \.self) { studio in
                        Text(studio)
                            .tag(studio)
                            .lineLimit(2)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                .pickerStyle(WheelPickerStyle())
            }
        }
        .onChange(of: studioSession3) { newValue in
            print("Studio 3 selected: \(newValue)")
        }
    }
    
    // Add credits step
    private var creditsStep: some View {
        VStack(spacing: 20) {
            Image(systemName: "star.circle.fill")
                .font(.system(size: 60))
                .foregroundColor(.yellow)
            
            Text("Credits")
                .font(.title)
                .bold()
            
            VStack(alignment: .leading, spacing: 12) {
                Text("Developed by:")
                    .font(.headline)
                Text("Miles Hedrick")
                    .font(.body)
                
                Text("Special Thanks:")
                    .font(.headline)
                    .padding(.top)
                Text("ABHS Staff & Students")
                    .font(.body)
                
                Text("Version 1.0")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding(.top)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding()
            .background(Color.gray.opacity(0.1))
            .cornerRadius(12)
        }
        .padding()
    }
    
    private var navigationButtons: some View {
        HStack {
            if currentStep > 0 {
                Button("Back") {
                    currentStep -= 1
                }
            }
            
            Spacer()
            
            if currentStep < 8 {
                Button("Next") {
                    if currentStep == 2 && name.trimmingCharacters(in: .whitespaces).isEmpty {
                        errorMessage = "Please enter your name"
                        showError = true
                        return
                    }
                    if currentStep == 3 && !isValidEmail(email) {
                        errorMessage = "Please enter a valid email address"
                        showError = true
                        return
                    }
                    currentStep += 1
                }
            } else {
                Button("Complete") {
                    if !isValidInput() {
                        errorMessage = "Please fill in all fields correctly"
                        showError = true
                        return
                    }
                    completeOnboarding()
                }
                .disabled(!isValidInput())
            }
        }
        .padding()
    }
    
    private func completeOnboarding() {
        Task {
            do {
                try await userSettings.submitUserData(
                    name: name,
                    email: email,
                    className: selectedClass,
                    grade: selectedGrade,
                    studioSession1: studioSession1,
                    studioSession2: studioSession2,
                    studioSession3: studioSession3
                )
            } catch {
                DispatchQueue.main.async {
                    if let urlError = error as? URLError {
                        switch urlError.code {
                        case .notConnectedToInternet:
                            errorMessage = "Please check your internet connection and try again."
                        case .timedOut:
                            errorMessage = "Request timed out. Please try again."
                        default:
                            errorMessage = "Network error: \(urlError.localizedDescription)"
                        }
                    } else {
                        errorMessage = error.localizedDescription
                    }
                    showError = true
                }
            }
        }
    }
    
    private func isValidInput() -> Bool {
        !name.trimmingCharacters(in: .whitespaces).isEmpty &&
        !email.trimmingCharacters(in: .whitespaces).isEmpty &&
        !selectedClass.isEmpty &&
        !selectedGrade.isEmpty &&
        !studioSession1.isEmpty &&
        !studioSession2.isEmpty &&
        !studioSession3.isEmpty
    }
    
    private func isValidEmail(_ email: String) -> Bool {
        let emailPattern = "[A-Z0-9a-z._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,64}"
        let emailPredicate = NSPredicate(format: "SELF MATCHES %@", emailPattern)
        return emailPredicate.evaluate(with: email)
    }
}

// Add error response model
struct ErrorResponse: Codable {
    let success: Bool
    let error: String
    let details: String?
}

// Add this new view for studio details
struct StudioTile: View {
    let studio: String
    let session: String
    let studentCount: Int
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(studio)
                .font(.headline)
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)
            Text("Session \(session)")
                .font(.subheadline)
                .foregroundColor(.secondary)
            Text("\(studentCount) students")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(width: 200)
        .padding()
        .background(Color.blue.opacity(0.1))
        .cornerRadius(8)
    }
}

struct StudioDetailView: View {
    let studioName: String
    let sessionNumber: String
    let students: [Student]
    
    var body: some View {
        List(students) { student in
            StudentRow(student: student)
        }
        .navigationTitle("\(studioName), Session \(sessionNumber)")
    }
}

// MARK: - App Entry Point
@main
struct StudentFilterApp: App {
    @StateObject private var userSettings = UserSettings()
    @StateObject private var firstLaunchManager = FirstLaunchManager()
    
    init() {
        // Initialize Google Mobile Ads SDK
        GADMobileAds.sharedInstance().start(completionHandler: nil)
    }
    
    var body: some Scene {
        WindowGroup {
            if userSettings.isOnboarded {
                ContentView()
                    .environmentObject(userSettings)
                    .alert("Review Update Coming Soon!", isPresented: $firstLaunchManager.showUpdatePopup) {
                        Button("OK") {
                            firstLaunchManager.markPopupAsSeen()
                        }
                    } message: {
                        Text("We're excited to announce that a new review feature will be coming soon! Stay tuned for updates.")
                    }
            } else {
                OnboardingView(userSettings: userSettings)
            }
        }
    }
}

// Add new Settings related models
class ProSubscription: ObservableObject {
    @Published var isProMember: Bool {
        didSet {
            UserDefaults.standard.set(isProMember, forKey: "isProMember")
        }
    }
    
    init() {
        self.isProMember = UserDefaults.standard.bool(forKey: "isProMember")
    }
    
    func upgradeToPro() {
        // In a real app, this would handle payment processing
        isProMember = true
    }
}

// Add Settings View
struct SettingsView: View {
    @Environment(\.presentationMode) var presentationMode
    @ObservedObject var userSettings: UserSettings
    @StateObject private var proSubscription = ProSubscription()
    @StateObject private var viewModel = StudentViewModel()
    
    @State private var showingStudioPicker = false
    @State private var selectedStudio1: String
    @State private var selectedStudio2: String
    @State private var selectedStudio3: String
    @State private var showingAlert = false
    @State private var alertMessage = ""
    
    init(userSettings: UserSettings) {
        self.userSettings = userSettings
        _selectedStudio1 = State(initialValue: userSettings.userAccount?.studioSession1 ?? "")
        _selectedStudio2 = State(initialValue: userSettings.userAccount?.studioSession2 ?? "")
        _selectedStudio3 = State(initialValue: userSettings.userAccount?.studioSession3 ?? "")
    }
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Account Information")) {
                    if let user = userSettings.userAccount {
                        Text("Name: \(user.name)")
                        Text("Email: \(user.email)")
                        Text("Class: \(user.className)")
                        Text("Grade: \(user.grade)")
                    }
                }
                
                Section(header: Text("Studio Selections")) {
                    Picker("Studio 1", selection: $selectedStudio1) {
                        ForEach(viewModel.availableStudios, id: \.self) { studio in
                            Text(studio).tag(studio)
                        }
                    }
                    
                    Picker("Studio 2", selection: $selectedStudio2) {
                        ForEach(viewModel.availableStudios, id: \.self) { studio in
                            Text(studio).tag(studio)
                        }
                    }
                    
                    Picker("Studio 3", selection: $selectedStudio3) {
                        ForEach(viewModel.availableStudios, id: \.self) { studio in
                            Text(studio).tag(studio)
                        }
                    }
                    
                    Button("Update Studio Selections") {
                        updateStudioSelections()
                    }
                }
                
                Section(header: Text("Pro Subscription")) {
                    if proSubscription.isProMember {
                        HStack {
                            Text("Pro Member")
                            Spacer()
                            Image(systemName: "checkmark.seal.fill")
                                .foregroundColor(.green)
                        }
                    } else {
                        VStack(alignment: .leading) {
                            Text("Upgrade to Pro")
                                .font(.headline)
                            Text("Get access to premium features")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                            Button("Upgrade Now - $4.99") {
                                proSubscription.upgradeToPro()
                            }
                            .padding(.vertical, 8)
                        }
                    }
                }
                
                Section {
                    Button("Sign Out") {
                        signOut()
                    }
                    .foregroundColor(.red)
                }
            }
            .navigationTitle("Settings")
            .navigationBarItems(trailing: Button("Done") {
                presentationMode.wrappedValue.dismiss()
            })
            .alert(isPresented: $showingAlert) {
                Alert(
                    title: Text("Update Status"),
                    message: Text(alertMessage),
                    dismissButton: .default(Text("OK"))
                )
            }
        }
    }
    
    private func updateStudioSelections() {
        guard let user = userSettings.userAccount else { return }
        
        Task {
            do {
                try await userSettings.submitUserData(
                    name: user.name,
                    email: user.email,
                    className: user.className,
                    grade: user.grade,
                    studioSession1: selectedStudio1,
                    studioSession2: selectedStudio2,
                    studioSession3: selectedStudio3
                )
                alertMessage = "Studio selections updated successfully"
                showingAlert = true
            } catch {
                alertMessage = "Failed to update: \(error.localizedDescription)"
                showingAlert = true
            }
        }
    }
    
    private func signOut() {
        userSettings.userAccount = nil
        userSettings.isOnboarded = false
        presentationMode.wrappedValue.dismiss()
    }
}

// Create a UIViewRepresentable wrapper for the GADBannerView
struct BannerView: UIViewRepresentable {
    func makeUIView(context: Context) -> GADBannerView {
        let banner = GADBannerView()
        banner.adUnitID = "ca-app-pub-5489746041402037/1688107917"
        banner.rootViewController = UIApplication.shared.windows.first?.rootViewController
        let request = GADRequest()
        banner.load(request)
        return banner
    }

    func updateUIView(_ uiView: GADBannerView, context: Context) {}
}

// Add a view modifier to add the banner to any view
struct BannerViewModifier: ViewModifier {
    func body(content: Content) -> some View {
        VStack(spacing: 0) {
            content
            BannerView()
                .frame(height: 50)
        }
    }
}

// Add an extension to View to make it easier to use
extension View {
    func withBannerAd() -> some View {
        modifier(BannerViewModifier())
    }
}

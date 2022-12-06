//
//  SearchView.swift
//  swifty-companion
//
//  Created by Bryan Ledda on 30/11/2022.
//

import SwiftUI

struct SearchView: View {
    @State private var tmpInput: String = "";
    @State private var search: Bool = true;
    @State private var user: User = User();
    @State private var showAlert = false
    @State private var titleError: String = "";
    @State private var messageError: String = "";
    @State private var isRequestInProgress: Bool = false;
	@State private var disabledSearchBar: Bool = false;
	@State private var msgLoading: String = "";
	
	func runSeach() {
		disabledSearchBar = true;
		msgLoading = "Initialisation request";
		Task() {
			isRequestInProgress = true;
			tmpInput = tmpInput.lowercased();
			tmpInput = tmpInput.replacingOccurrences(of: " ", with: "-", options: .literal, range: nil);
			msgLoading = "Search user";
			var value: String = await Api.getValue("/v2/users/\(tmpInput)");
			value = value.replacingOccurrences(of: "validated?", with: "validated", options: .literal, range: nil);
			do {
				var data: Data = value.data(using: .utf8)!;
				user = try JSONDecoder().decode(User.self, from: data);
				if (user.id != nil) {
					msgLoading = "Information coalitions";
					value = await Api.getValue("/v2/users/\(String(user.id!))/coalitions?coalition[cover]");
					data = value.data(using: .utf8)!;
					user.coalitions = try JSONDecoder().decode([Coalition].self, from: data);
					if (user.coalitions == nil || user.coalitions!.isEmpty) {
						errorNotCoalition();
					} else {
						for n in 0..<user.cursus_users!.count {
							let cursusUsers: CursusUser = user.cursus_users![n]!;
							let idString: String = String(cursusUsers.cursus.id);
							msgLoading = "Get empty skill for \(cursusUsers.cursus.name)";
							let value = await Api.getValue("/v2/cursus/\(idString)/skills");
							let data: Data = value.data(using: .utf8)!;
							let skills: [SkillItem] = try JSONDecoder().decode([SkillItem].self, from: data);
							skills.forEach({skill in
								var found: Bool = false;
								user.cursus_users![n]!.skills.forEach({sk in
									if (sk.name == skill.name) {
										found = true;
									}
								})
								if (!found) {
									user.cursus_users![n]!.skills.append(Skill(name: skill.name, level: 0.0))
								}
							})
						}
						msgLoading = "Get locations";
						var page: Int = 1;
						var locations: [Location] = [];
						while (true) {
							value = await Api.getValue("/v2/users/\(String(user.id!))/locations?per_page=100&page=\(page)");
							data = value.data(using: .utf8)!;
							let temp: [Location] = try JSONDecoder().decode([Location].self, from: data)
							if (temp.isEmpty) {
								break ;
							}
							for tmp in temp {
								locations.append(tmp);
							}
							if (temp.count < 100) {
								break ;
							}
							page += 1;
							msgLoading = "Locations found: \(locations.count)";
						}
						user.locations = locations;
						
						var achievements: [Achievement] = [];
						for campus in user.campus! {
							page = 1;
							while (true) {
								msgLoading = "Get achievements campus \(campus.name) in page \(page)";
								value = await Api.getValue("/v2/campus/\(campus.id)/achievements?per_page=100&page=\(page)");
								data = value.data(using: .utf8)!;
								let tmp: [Achievement] = try JSONDecoder().decode([Achievement].self, from: data);
								if (tmp.isEmpty) {
									break ;
								}
								for t in tmp {
									achievements.append(t);
								}
								if (tmp.count < 100) {
									break ;
								}
								page += 1;
							}
						}
						
						var achievementsUser: [AchievementUserItem] = [];
						page = 1;
						while (true) {
							msgLoading = "Get achievements user in page \(page)";
							value = await Api.getValue("/v2/achievements_users?filter[user_id]=\(String(user.id!))&per_page=100&page=\(page)");
							data = value.data(using: .utf8)!;
							let tmp: [AchievementUserItem] = try JSONDecoder().decode([AchievementUserItem].self, from: data);
							if (tmp.isEmpty) {
								break ;
							}
							for t in tmp {
								achievementsUser.append(t);
							}
							if (tmp.count < 100) {
								break ;
							}
							page += 1;
						}
						
						user.achivements = [];
						for achievementUser in achievementsUser {
							for achievement in achievements {
								if (achievement.id == achievementUser.achievement_id) {
									user.achivements?.append(achievement);
									break ;
								}
							}
						}

						search = false;
					}
				} else {
					errorUserNotFound();
				}
			} catch {
				errorRequest(error);
			}
			isRequestInProgress = false;
			disabledSearchBar = false;
			msgLoading = "";
		}
	}
	
	func errorNotCoalition() -> Void {
		titleError = "Error user";
		messageError = "This user as not coalition! realy ?";
		showAlert = true;
	}
	
	func errorUserNotFound() -> Void {
		titleError = "User not found";
		messageError = "\(tmpInput) is not valid user 42";
		showAlert = true;
	}
	
	func errorRequest(_ error: any Error) -> Void {
		titleError = "Request error";
		messageError = "Error: \(error)";
		showAlert = true;
	}
	
	func runAlert() -> Alert {
		return Alert(
			title: Text(titleError),
			message: Text(messageError)
		)
	}
	
    var body: some View {
        if (search) {
			NavigationStack {
				Image("logo42Nice")
					.resizable()
					.scaledToFit()
					.frame(width: 100, height: 100)
						.navigationTitle("Search user 42");
				if isRequestInProgress {
					ProgressView(msgLoading);
				}
			}.searchable(text: $tmpInput)
				.onSubmit(of: .search, runSeach)
				.alert(isPresented: $showAlert) { runAlert() }
				.disabled(disabledSearchBar);
        } else {
            IntraView(user);
        }
    }
}

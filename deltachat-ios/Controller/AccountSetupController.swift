//
//  AccountSetupController.swift
//  deltachat-ios
//
//  Created by Bastian van de Wetering on 02.04.19.
//  Copyright © 2019 Jonas Reinsch. All rights reserved.
//

import SafariServices
import UIKit
import UICircularProgressRing

class AccountSetupController: UITableViewController {

	weak var coordinator: AccountSetupCoordinator?

	private var skipOauth = false

	private var backupProgressObserver: Any?
	private var configureProgressObserver: Any?
	private var oauth2Observer: Any?

	lazy var configProgressIndicator: UICircularProgressRing = {
		let progress = UICircularProgressRing()
		progress.style = UICircularRingStyle.inside
		progress.outerRingColor = UIColor.clear
		progress.maxValue = 100
		progress.innerRingColor = DCColors.primary
		progress.innerRingWidth = 2
		progress.startAngle = 270
		progress.fontColor = UIColor.lightGray
		progress.font = UIFont.systemFont(ofSize: 12)
		return progress
	}()

	lazy var configProgressAlert: UIAlertController = {
		let alert = UIAlertController(title: "Configuring Account", message: "\n\n\n", preferredStyle: .alert)
		// temp workaround: add 3 newlines to let alertbox grow to fit progressview
		let progressView = configProgressIndicator
		progressView.translatesAutoresizingMaskIntoConstraints = false
		alert.view.addSubview(progressView)
		progressView.centerXAnchor.constraint(equalTo: alert.view.centerXAnchor).isActive = true
		progressView.centerYAnchor.constraint(equalTo: alert.view.centerYAnchor, constant: 0).isActive = true
		progressView.heightAnchor.constraint(equalToConstant: 65).isActive = true
		progressView.widthAnchor.constraint(equalToConstant: 65).isActive = true
		alert.addAction(UIAlertAction(title: "Cancel", style: .cancel, handler: loginCancelled(_:)))
		return alert
	}()

	private lazy var emailCell: TextFieldCell = {
		let cell = TextFieldCell.makeEmailCell(delegate: self)
		cell.textField.tag = 0
		cell.textField.accessibilityIdentifier = "emailTextField" // will be used to eventually show oAuth-Dialogue when pressing return key
		cell.setText(text: MRConfig.addr ?? nil)
		cell.textField.delegate = self
		return cell
	}()

	private lazy var passwordCell: TextFieldCell = {
		let cell = TextFieldCell.makePasswordCell(delegate: self)
		cell.textField.tag = 1
		cell.accessibilityIdentifier = "passwordCell" // will be used to eventually show oAuth-Dialogue when selecting
		cell.setText(text: MRConfig.mailPw ?? nil)
		return cell
	}()

	private lazy var restoreCell: ActionCell = {
		let cell = ActionCell(frame: .zero)
		cell.actionTitle = "Restore from backup"
		cell.accessibilityIdentifier = "restoreCell"
		return cell
	}()

	lazy var imapServerCell: TextFieldCell = {
		let cell = TextFieldCell(description: "IMAP Server", placeholder: MRConfig.mailServer ?? MRConfig.configuredMailServer, delegate: self)
		cell.accessibilityIdentifier = "IMAPServerCell"
		cell.textField.tag = 2
		return cell
	}()

	lazy var imapUserCell: TextFieldCell = {
		let cell = TextFieldCell(description: "IMAP User", placeholder: MRConfig.mailUser ?? MRConfig.configuredMailUser, delegate: self)
		cell.accessibilityIdentifier = "IMAPUserCell"
		cell.textField.tag = 3
		return cell
	}()

	lazy var imapPortCell: UITableViewCell = {
		let cell = UITableViewCell(style: .value1, reuseIdentifier: nil)
		cell.textLabel?.text = "IMAP Port"
		cell.accessoryType = .disclosureIndicator
		cell.detailTextLabel?.text = MRConfig.mailPort ?? MRConfig.configuredMailPort
		cell.accessibilityIdentifier = "IMAPPortCell"
		cell.selectionStyle = .none
		return cell
	}()

	lazy var imapSecurityCell: UITableViewCell = {
		let text = "\(MRConfig.getImapSecurity())"
		let cell = UITableViewCell(style: .value1, reuseIdentifier: nil)
		cell.textLabel?.text = "IMAP Security"
		// let cell = TextFieldCell(description: "IMAP Security", placeholder: text, delegate: self)
		cell.accessibilityIdentifier = "IMAPSecurityCell"
		cell.accessoryType = .disclosureIndicator
		cell.detailTextLabel?.text = "\(MRConfig.getImapSecurity())"
		cell.selectionStyle = .none
		return cell
	}()

	lazy var smtpServerCell: TextFieldCell = {
		let cell = TextFieldCell(description: "SMTP Server", placeholder: MRConfig.sendServer ?? MRConfig.configuredSendServer, delegate: self)
		cell.accessibilityIdentifier = "SMTPServerCell"
		cell.textField.tag = 4
		return cell
	}()

	lazy var smtpUserCell: TextFieldCell = {
		let cell = TextFieldCell(description: "SMTP User", placeholder: MRConfig.sendUser ?? MRConfig.configuredSendUser, delegate: self)
		cell.accessibilityIdentifier = "SMTPUserCell"
		cell.textField.tag = 5
		return cell
	}()

	lazy var smtpPortCell: UITableViewCell = {
		let cell = UITableViewCell(style: .value1, reuseIdentifier: nil)
		cell.textLabel?.text = "SMTP Port"
		cell.accessoryType = .disclosureIndicator
		cell.detailTextLabel?.text = MRConfig.sendPort ?? MRConfig.configuredSendPort
		cell.accessibilityIdentifier = "SMTPPortCell"
		cell.selectionStyle = .none
		return cell
	}()

	lazy var smtpPasswordCell: TextFieldCell = {
		let cell = TextFieldCell(description: "SMTP Password", placeholder: "*************", delegate: self)
		cell.accessibilityIdentifier = "SMTPPasswordCell"
		cell.textField.tag = 6
		return cell
	}()

	lazy var smtpSecurityCell: UITableViewCell = {
		let security = "\(MRConfig.getSmtpSecurity())"
		let cell = UITableViewCell(style: .value1, reuseIdentifier: nil)
		cell.textLabel?.text = "SMTP Security"
		cell.detailTextLabel?.text = security
		cell.accessibilityIdentifier = "SMTPSecurityCell"
		cell.accessoryType = .disclosureIndicator
		cell.selectionStyle = .none
		return cell
	}()

	// this loginButton can be enabled and disabled
	lazy var loginButton: UIBarButtonItem = UIBarButtonItem(title: "Login", style: .done, target: self, action: #selector(loginButtonPressed))

	private lazy var basicSectionCells: [UITableViewCell] = [emailCell, passwordCell]
	private lazy var restoreCells: [UITableViewCell] = [restoreCell]
	private lazy var advancedSectionCells: [UITableViewCell] = [
		imapServerCell,
		imapUserCell,
		imapPortCell,
		imapSecurityCell,
		smtpServerCell,
		smtpUserCell,
		smtpPortCell,
		smtpPasswordCell,
		smtpSecurityCell
	]

	private var advancedSectionShowing: Bool = false

	init() {
		super.init(style: .grouped)
		hidesBottomBarWhenPushed = true
	}

	required init?(coder _: NSCoder) {
		fatalError("init(coder:) has not been implemented")
	}

	override func viewDidLoad() {
		super.viewDidLoad()
		title = "Login to your server"
		// navigationItem.leftBarButtonItem = UIBarButtonItem(title: "Close", style: .plain, target: self, action: #selector(closeButtonPressed))
		navigationItem.rightBarButtonItem = loginButton
	}

	override func viewWillAppear(_ animated: Bool) {
		super.viewWillAppear(animated)
		// needs to be changed if returning from portSettingsController
		smtpPortCell.detailTextLabel?.text = MRConfig.sendPort ?? MRConfig.configuredSendPort
		imapPortCell.detailTextLabel?.text = MRConfig.mailPort ?? MRConfig.configuredMailPort
		smtpSecurityCell.detailTextLabel?.text = SecurityConverter.convertHexToString(type: .SMTPSecurity, hex: MRConfig.getSmtpSecurity())
		imapSecurityCell.detailTextLabel?.text  = SecurityConverter.convertHexToString(type: .IMAPSecurity, hex: MRConfig.getImapSecurity())
	}

	override func viewDidAppear(_ animated: Bool) {
		super.viewDidAppear(animated)
		addProgressHudEventListener()
		// loginButton.isEnabled = false
	}

	override func viewWillDisappear(_ animated: Bool) {
		resignFirstResponderOnAllCells()
	}

	override func viewDidDisappear(_: Bool) {

		let nc = NotificationCenter.default
		if let backupProgressObserver = self.backupProgressObserver {
			nc.removeObserver(backupProgressObserver)
		}
		if let configureProgressObserver = self.configureProgressObserver {
			nc.removeObserver(configureProgressObserver)
		}
		if let oauth2Observer = self.oauth2Observer {
			nc.removeObserver(oauth2Observer)
		}
	}

	// MARK: - Table view data source

	override func numberOfSections(in _: UITableView) -> Int {
		// #warning Incomplete implementation, return the number of sections
		return 3
	}

	override func tableView(_: UITableView, numberOfRowsInSection section: Int) -> Int {
		// #warning Incomplete implementation, return the number of rows
		if section == 0 {
			return basicSectionCells.count
		} else if section == 1 {
			return restoreCells.count
		} else {
			return advancedSectionShowing ? advancedSectionCells.count : 0
		}
	}

	override func tableView(_: UITableView, titleForHeaderInSection section: Int) -> String? {
		if section == 2 {
			return "Advanced"
		} else {
			return nil
		}
	}

	override func tableView(_: UITableView, viewForHeaderInSection section: Int) -> UIView? {
		if section == 2 {
			// Advanced Header
			let advancedView = AdvancedSectionHeader()
			advancedView.handleTap = toggleAdvancedSection
			// set tapHandler
			return advancedView

		} else {
			return nil
		}
	}

	override func tableView(_: UITableView, heightForHeaderInSection _: Int) -> CGFloat {
		return 36.0
	}

	override func tableView(_: UITableView, titleForFooterInSection section: Int) -> String? {
		if section == 0 {
			return "There are no Delta Chat servers, your data stays on your device!"
		} else if section == 2 {
			if advancedSectionShowing {
				return "For known email providers additional settings are setup automatically. Sometimes IMAP needs to be enabled in the web frontend. Consult your email provider or friends for help"
			} else {
				return nil
			}
		} else {
			return nil
		}
	}

	override func tableView(_: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
		let section = indexPath.section
		let row = indexPath.row

		if section == 0 {
			// basicSection
			return basicSectionCells[row]
		} else if section == 1 {
			return restoreCells[row]
		} else {
			// advancedSection
			return advancedSectionCells[row]
		}
	}

	override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
		guard let tappedCell = tableView.cellForRow(at: indexPath) else { return }
		// handle tap on password -> show oAuthDialogue
		if let textFieldCell = tappedCell as? TextFieldCell {
			if textFieldCell.accessibilityIdentifier == "passwordCell" {
				if let emailAdress = textFieldCell.getText() {
					_ = showOAuthAlertIfNeeded(emailAddress: emailAdress, handleCancel: nil)
				}
			}
		}

		if tappedCell.accessibilityIdentifier == "restoreCell" {
			restoreBackup()
		} else if tappedCell.accessibilityIdentifier == "IMAPPortCell" {
			coordinator?.showImapPortOptions()
		} else if tappedCell.accessibilityIdentifier == "SMTPPortCell" {
			coordinator?.showSmtpPortsOptions()
		} else if tappedCell.accessibilityIdentifier == "IMAPSecurityCell" {
			coordinator?.showImapSecurityOptions()
		} else if tappedCell.accessibilityIdentifier == "SMTPSecurityCell" {
			coordinator?.showSmptpSecurityOptions()
		}
	}

	private func toggleAdvancedSection(button: UILabel) {
		let willShow = !advancedSectionShowing

		// extract indexPaths from advancedCells
		let advancedIndexPaths: [IndexPath] = advancedSectionCells.indices.map { IndexPath(row: $0, section: 2) }

		// advancedSectionCells.indices.map({indexPaths.append(IndexPath(row: $0, section: 1))}

		// set flag before delete/insert operation, because cellForRowAt will be triggered and uses this flag
		advancedSectionShowing = willShow

		button.text = willShow ? "Hide" : "Show"

		if willShow {
			tableView.insertRows(at: advancedIndexPaths, with: .fade)
		} else {
			tableView.deleteRows(at: advancedIndexPaths, with: .fade)
		}
		tableView.reloadData() // to re-organize footer view (without that sometimes advanced section footer is still visible)
	}

	@objc private func loginButtonPressed() {
		guard let emailAddress = emailCell.getText() else {
			return // handle case when either email or pw fields are empty
		}

		let oAuthStarted = showOAuthAlertIfNeeded(emailAddress: emailAddress, handleCancel: loginButtonPressed)
		// if canceled we will run this method again but this time oAuthStarted will be false

		if oAuthStarted {
			// the loginFlow will be handled by oAuth2
			return
		}

		let password = passwordCell.getText() ?? "" // empty passwords are ok -> for oauth there is no password needed

		login(emailAddress: emailAddress, password: password)
	}

	private func login(emailAddress: String, password: String, skipAdvanceSetup: Bool = false) {
		resignFirstResponderOnAllCells()	// this will resign focus from all textFieldCells so the keyboard wont pop up anymore
		MRConfig.addr = emailAddress
		MRConfig.mailPw = password

		if !skipAdvanceSetup {
			evaluluateAdvancedSetup() // this will set MRConfig related to advanced fields
		}

		print("oAuth-Flag when loggin in: \(MRConfig.getAuthFlags())")
		dc_configure(mailboxPointer)
		showProgressHud()
	}

	@objc func closeButtonPressed() {
		dismiss(animated: true, completion: nil)
	}

	// returns true if needed
	private func showOAuthAlertIfNeeded(emailAddress: String, handleCancel: (() -> Void)?) -> Bool {
		if skipOauth {
			assert(MRConfig.getAuthFlags() == Int(DC_LP_AUTH_NORMAL))
			// user has previously denied oAuth2-setup
			return false
		}

		guard let oAuth2UrlPointer = dc_get_oauth2_url(mailboxPointer, emailAddress, "chat.delta:/auth") else {
			MRConfig.setAuthFlags(flags: Int(DC_LP_AUTH_NORMAL))
			return false
		}

		let oAuth2Url = String(cString: oAuth2UrlPointer)

		if let url = URL(string: oAuth2Url) {
			let title = "Continue with simplified setup"
			// swiftlint:disable all
			let message = "The entered e-mail address supports a simplified setup (oAuth2).\n\nIn the next step, please allow Delta Chat to act as your Chat with E-Mail app.\n\nThere are no Delta Chat servers, your data stays on your device."

			let oAuthAlertController = UIAlertController(title: title, message: message, preferredStyle: .alert)
			let confirm = UIAlertAction(title: "Confirm", style: .default, handler: {
				[unowned self] _ in
				let nc = NotificationCenter.default
				self.oauth2Observer = nc.addObserver(self, selector: #selector(self.oauthLoginApproved), name: NSNotification.Name("oauthLoginApproved"), object: nil)
				self.launchOAuthBrowserWindow(url: url)
			})
			let cancel = UIAlertAction(title: "Cancel", style: .cancel, handler: {
				_ in
				MRConfig.setAuthFlags(flags: Int(DC_LP_AUTH_NORMAL))
				self.skipOauth = true
				handleCancel?()

			})
			oAuthAlertController.addAction(confirm)
			oAuthAlertController.addAction(cancel)

			present(oAuthAlertController, animated: true, completion: nil)
			return true
		} else {
			return false
		}
	}

	@objc func oauthLoginApproved(notification: Notification) {
		guard let userInfo = notification.userInfo, let token = userInfo["token"] as? String, let emailAddress = emailCell.getText() else {
			return
		}
		passwordCell.setText(text: token)
		MRConfig.setAuthFlags(flags: Int(DC_LP_AUTH_OAUTH2))
		login(emailAddress: emailAddress, password: token, skipAdvanceSetup: true)
	}

	private func launchOAuthBrowserWindow(url: URL) {
		UIApplication.shared.open(url) // this opens safari as seperate app
	}

	private func addProgressHudEventListener() {
		let nc = NotificationCenter.default
		backupProgressObserver = nc.addObserver(
			forName: dcNotificationBackupProgress,
			object: nil,
			queue: nil
		) {
			notification in
			if let ui = notification.userInfo {
				if ui["error"] as! Bool {
					self.updateProgressHud(error: ui["errorMessage"] as? String)
					// self.hudHandler.setHudError(ui["errorMessage"] as? String)
				} else if ui["done"] as! Bool {
					self.updateProgressHudSuccess(callback: self.handleLoginSuccess)
				} else {
					self.updateProgressHudValue(value: ui["progress"] as! Int)
				}
			}
		}
		configureProgressObserver = nc.addObserver(
			forName: dcNotificationConfigureProgress,
			object: nil,
			queue: nil
		) {
			notification in
			if let ui = notification.userInfo {
				if ui["error"] as! Bool {
					self.updateProgressHud(error: ui["errorMessage"] as? String)
					// self.hudHandler.setHudError(ui["errorMessage"] as? String)
				} else if ui["done"] as! Bool {
					self.updateProgressHudSuccess(callback: self.handleLoginSuccess)
				} else {
					self.updateProgressHudValue(value: ui["progress"] as! Int)
				}
			}
		}
	}

	private func evaluluateAdvancedSetup() {
		for cell in advancedSectionCells {
			if let textFieldCell = cell as? TextFieldCell {
				switch cell.accessibilityIdentifier {
				case "IMAPServerCell":
					MRConfig.mailServer = textFieldCell.getText() ?? nil
				case "IMAPUserCell":
					MRConfig.mailUser = textFieldCell.getText() ?? nil
				case "IMAPPortCell":
					MRConfig.mailPort = textFieldCell.getText() ?? nil
				case "IMAPSecurityCell":
					let flag = 0
					MRConfig.setImapSecurity(imapFlags: flag)
				case "SMTPServerCell":
					MRConfig.sendServer = textFieldCell.getText() ?? nil
				case "SMTPSUserCell":
					MRConfig.sendUser = textFieldCell.getText() ?? nil
				case "SMTPPortCell":
					MRConfig.sendPort = textFieldCell.getText() ?? nil
				case "SMTPPasswordCell":
					MRConfig.sendPw = textFieldCell.getText() ?? nil
				case "SMTPSecurityCell":
					let flag = 0
					MRConfig.setSmtpSecurity(smptpFlags: flag)
				default:
					logger.info("unknown identifier", cell.accessibilityIdentifier ?? "")
				}
			}
		}
	}

	private func restoreBackup() {
		logger.info("restoring backup")
		if MRConfig.configured {
			return
		}
		let documents = NSSearchPathForDirectoriesInDomains(.documentDirectory, .userDomainMask, true)
		if !documents.isEmpty {
			logger.info("looking for backup in: \(documents[0])")

			if let file = dc_imex_has_backup(mailboxPointer, documents[0]) {
				logger.info("restoring backup: \(String(cString: file))")

				// hudHandler.showBackupHud("Restoring Backup")
				dc_imex(mailboxPointer, DC_IMEX_IMPORT_BACKUP, file, nil)

				return
			}

			let alert = UIAlertController(title: "Can not restore", message: "No Backup found", preferredStyle: .alert)
			alert.addAction(UIAlertAction(title: "OK", style: .cancel, handler: { _ in

			}))
			present(alert, animated: true, completion: nil)
			return
		}

		logger.error("no documents directory found")
	}

	private func handleLoginSuccess() {
		// used when login hud successfully went trough
		dismiss(animated: true, completion: nil)
	}

	private func resignFirstResponderOnAllCells() {
		let _ = basicSectionCells.map({
			resignCell(cell: $0)
		})

		let _ = advancedSectionCells.map({
			resignCell(cell: $0)
			}
		)
	}

	func resignCell(cell: UITableViewCell) {
		if let c = cell as? TextFieldCell {
			c.textField.resignFirstResponder()
		}
	}
}

extension AccountSetupController: UITextFieldDelegate {
	func textFieldShouldReturn(_ textField: UITextField) -> Bool {
		let currentTag = textField.tag
		if let nextField = tableView.viewWithTag(currentTag + 1) as? UITextField {
			if nextField.tag > 1, !advancedSectionShowing {
				// gets here when trying to activate a collapsed cell
				return false
			}
			nextField.becomeFirstResponder()
		}
		return false
	}

	func textFieldDidBeginEditing(_ textField: UITextField) {
		if textField.accessibilityIdentifier == "emailTextField" {
			// this will re-enable possible oAuth2-login
			skipOauth = false
		}
	}

	func textFieldDidEndEditing(_ textField: UITextField) {
		if textField.accessibilityIdentifier == "emailTextField" {
			let _ = showOAuthAlertIfNeeded(emailAddress: textField.text ?? "", handleCancel: {
				self.passwordCell.textField.becomeFirstResponder()
			})
		}
	}
}

class AdvancedSectionHeader: UIView {
	var handleTap: ((UILabel) -> Void)?

	private var label: UILabel = {
		let label = UILabel()
		label.text = "ADVANCED"
		label.font = UIFont.systemFont(ofSize: 15)
		label.textColor = UIColor.darkGray
		return label
	}()

	/*
	why UILabel, why no UIButton? For unknown reasons UIButton's target function was not triggered when one of the textfields in the tableview was active -> used label as workaround
	*/
	private lazy var toggleButton: UILabel = {
		let label = UILabel()
		label.text = "Show"
		label.font = UIFont.systemFont(ofSize: 15, weight: .medium)
		label.textColor = UIColor.systemBlue
		return label
	}()

	init() {
		super.init(frame: .zero) // will be constraint from tableViewDelegate
		setupSubviews()
		let tap = UITapGestureRecognizer(target: self, action: #selector(viewTapped)) // use this if the whole header is supposed to be clickable
		addGestureRecognizer(tap)
	}

	required init?(coder _: NSCoder) {
		fatalError("init(coder:) has not been implemented")
	}

	func setupSubviews() {
		addSubview(label)
		label.translatesAutoresizingMaskIntoConstraints = false
		label.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 15).isActive = true
		label.centerYAnchor.constraint(equalTo: centerYAnchor, constant: 0).isActive = true
		addSubview(toggleButton)
		toggleButton.translatesAutoresizingMaskIntoConstraints = false
		toggleButton.leadingAnchor.constraint(equalTo: trailingAnchor, constant: -60).isActive = true // since button will change title it should be left aligned
		toggleButton.centerYAnchor.constraint(equalTo: label.centerYAnchor, constant: 0).isActive = true
	}

	@objc func buttonTapped(_: UIButton) {
		// handleTap?(button)
	}

	@objc func viewTapped() {
		handleTap?(toggleButton)
	}
}

extension AccountSetupController {

	func showProgressHud() {
		configProgressAlert.actions[0].isEnabled = true
		configProgressAlert.title = "Configuring Account"
		configProgressAlert.message = "\n\n\n"
		configProgressIndicator.alpha = 1
		configProgressIndicator.value = 0
		present(configProgressAlert, animated: true, completion: nil)

	}

	func updateProgressHud(error message: String?) {
		configProgressAlert.title = "Unable to Login!"
		configProgressAlert.message = message
		configProgressIndicator.alpha = 0
	}

	func updateProgressHudSuccess(callback: (()->())?) {
		configProgressAlert.actions[0].isEnabled = false
		configProgressIndicator.alpha = 0
		configProgressAlert.title = "Login Successful!"
		configProgressAlert.message = "You are ready to use Delta Chat."
		DispatchQueue.main.asyncAfter(deadline: .now() + 2, execute: {
			self.configProgressAlert.dismiss(animated: true) {
				self.handleLoginSuccess()
			}
		})
	}

	func updateProgressHudValue(value: Int?) {
		if let value = value {
			print("progress hud: \(value)")
			configProgressIndicator.value = CGFloat(value / 10)
		}
	}

	func loginCancelled(_ action: UIAlertAction) {
		MRConfig.addr = nil
		MRConfig.mailPw = nil
		DispatchQueue.global(qos: .background).async {
			dc_stop_ongoing_process(mailboxPointer)		// this function freezes UI so execute in background thread
		}
	}
}

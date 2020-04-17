import UIKit
import Social
import DcCore


class ShareViewController: SLComposeServiceViewController {

    class SimpleLogger: Logger {
        func verbose(_ message: String) {
            print("ShareViewController", "verbose", message)
        }

        func debug(_ message: String) {
            print("ShareViewController", "debug", message)
        }

        func info(_ message: String) {
            print("ShareViewController", "info", message)
        }

        func warning(_ message: String) {
            print("ShareViewController", "warning", message)
        }

        func error(_ message: String) {
            print("ShareViewController", "error", message)
        }
    }

    let logger = SimpleLogger()
    let dcContext = DcContext.shared
    var selectedChatId: Int?
    var selectedChat: DcChat?

    override func viewDidLoad() {
        super.viewDidLoad()
        // workaround for iOS13 bug
        if #available(iOS 13.0, *) {
            _ = NotificationCenter.default.addObserver(forName: UIResponder.keyboardDidShowNotification, object: nil, queue: .main) { (_) in
                if let layoutContainerView = self.view.subviews.last {
                    layoutContainerView.frame.size.height += 10
                }
            }
        }
    }

    override func presentationAnimationDidFinish() {

        let dbHelper = DatabaseHelper()
        if dbHelper.currentDatabaseLocation == dbHelper.sharedDbFile {
            dcContext.logger = self.logger
            dcContext.openDatabase(dbFile: dbHelper.sharedDbFile)
            selectedChatId = dcContext.getChatIdByContactId(contactId: Int(DC_CONTACT_ID_SELF))
            if let chatId = selectedChatId {
                selectedChat = dcContext.getChat(chatId: chatId)
            }
            reloadConfigurationItems()
        } else {
            cancel()
        }
    }

    override func isContentValid() -> Bool {
        // Do validation of contentText and/or NSExtensionContext attachments here
        return  !(contentText?.isEmpty ?? true)
    }

    override func didSelectPost() {
        // This is called after the user selects Post. Do the upload of contentText and/or NSExtensionContext attachments.
        logger.debug("did select post - \(String(describing: selectedChatId))")
        if let chatId = selectedChatId {
            let message = DcMsg(viewType: DC_MSG_TEXT)
            message.text = self.contentText
            message.sendInChat(id: chatId)
        }

        logger.debug("did select post - closeDatabase")
        dcContext.closeDatabase()
        // Inform the host that we're done, so it un-blocks its UI. Note: Alternatively you could call super's -didSelectPost, which will similarly complete the extension context.
        self.extensionContext!.completeRequest(returningItems: [], completionHandler: nil)
    }

    override func configurationItems() -> [Any]! {
         logger.debug("configurationItems")
        // To add configuration options via table cells at the bottom of the sheet, return an array of SLComposeSheetConfigurationItem here.

        let item = SLComposeSheetConfigurationItem()
        item?.title = String.localized("forward_to")
        item?.value = selectedChat?.name
        logger.debug("configurationItems chat name: \(String(describing: selectedChat?.name))")
        item?.tapHandler = {
            let chatListController = ChatListController(dcContext: self.dcContext, chatListDelegate: self)
            self.pushConfigurationViewController(chatListController)
        }

        return [item as Any]
    }
}

extension ShareViewController: ChatListDelegate {
    func onChatSelected(chatId: Int) {
        selectedChatId = chatId
        selectedChat = DcChat(id: chatId)
        reloadConfigurationItems()
        popConfigurationViewController()
    }
}

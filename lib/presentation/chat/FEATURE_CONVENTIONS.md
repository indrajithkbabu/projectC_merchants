# Chat Feature Conventions

WhatsApp-style Message inbox, plus visitor enquiry entry. On another store's product photo, a tap opens a composer (no suggestion chips); send writes one discussion for that photo, lists the store on Message, and opens the thread. Store-page long-press and the enquiry basket are unchanged.

## Mandatory Update Rule
- If chat screens, composer rules, or the shell entry change, update this file in the same change.

## UI Rules
- The second shell tab is **Message** for every account (chat icon, unread count). It lists chats only: people, stores, and groups. Customers see stores. Search plus filters All / Unread / Stores / Groups. **+** opens New chat (New group, Find stores, Invite friends, then Stores and Followers). An empty chat stays off the list until the first message. A group is listed as soon as it is created.
- One discussion opens the thread directly. Two or more open the discussion list: search, a Closed row, long-press to mark read or close, drag to reorder open rows. Reopen moves a discussion to the top. A discussion can have no product; its name is the date, and a second unnamed one the same day adds the time.
- On another store's catalogue, the header **chat** bubble opens that store's thread. Long-press selects photos (green check, `N selected`). **Ask about N** opens the enquiry basket. Send writes one message and one discussion per photo, then opens the thread. Those store chats appear on Message.
- The thread is a pushed route (`chat_thread_route`). The shell nav stays on the list only. A product discussion pins the product under the header. The composer is **+** to share, a lock for team-only notes, the field, and send. Team notes are amber `#E3B54E` and hidden from other stores. Long-press a message: Reply, Reply to team, Copy. `@Name` is blue `#3B9BE8` and leaves an @ on the row until that discussion is opened.
- Profile (tap the name) is mute, phone, and members grouped by store. Mute has no expiry. Muted chats still show unread and @, plus a slashed bell.
- Use `AppTextStyles`, `AppColors`, and `AppPadding`. A thread header is the discussion name over `Store · N people`. Incoming bubbles stay graphite. Your messages are white with black text. Names appear inside the bubble, and only in a group. Team notes use a dashed amber outline. Read ticks and @mentions use `#3B9BE8`.
- Lists leave `FloatingBottomNavBar.reservedHeight` inside the scroll view.
- Unread is a count. No "needs reply" label.

## Logic Ownership
- `ChatMockStore` holds threads, quick replies, and auto-reply text in memory.
- `ChatTab` copies the signed-in name, store name, and own-store catalogue into that store during build. It does not notify from that sync. Accounts without a store do not read `StoreProfileBloc`.
- An empty chat started from New chat stays off the list until the first message.
- Sending follows the open discussion. Sharing a product while a discussion is targeted attaches it inside that discussion. The lock sends a team-only note (`writerStore` is this store).
- The thread shows one discussion at a time. Other discussions stay on the discussion list.
- Opening a discussion marks it read and clears its @. Closed discussions are not selectable.
- Find stores reuses `ContactsTab(showBack: true)` with the shell contacts and listing blocs. Invite friends reuses `invite_friends_route`.
- Replace `ChatMockStore` when the API exists. Keep the screens on the same thread, discussion, and message shapes until the contract is known.

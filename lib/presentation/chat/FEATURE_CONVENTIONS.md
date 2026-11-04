# Chat Feature Conventions

Merchant chat UI, plus the visitor store-page enquiry entry (chat button, long-press, basket). The product-viewer “Ask about this” bar is still out of scope.

## Mandatory Update Rule
- If chat screens, composer rules, or the shell entry change, update this file in the same change.

## UI Rules
- Entry is the **Chats** tab immediately after **My store** on the own-store floating nav. Users without a store do not see it.
- On another store's catalogue, the header **chat** bubble opens that store's thread. Long-press selects photos (green check, `N selected`). **Ask about N** opens the enquiry basket. Send writes one message and one discussion per photo, then opens the thread. Those threads are outbound and do not appear in the merchant inbox.
- The thread is a pushed route (`chat_thread_route`). The shell nav stays on the list only.
- Use `AppTextStyles`, `AppColors`, and `AppPadding`. Own bubbles are the lighter neutral; the other side is the darker neutral. Read ticks use `#3B9BE8`. The auto-reply switch uses `#16A34A`.
- Lists leave `FloatingBottomNavBar.reservedHeight` inside the scroll view.
- Unread is the only badge. No "needs reply" label.

## Logic Ownership
- `ChatMockStore` holds threads, quick replies, and auto-reply text in memory.
- `ChatTab` copies the signed-in name, store name, and own-store catalogue into that store during build. It does not notify from that sync.
- An empty chat started from New chat stays off the list until the first message.
- Sending follows the open discussion unless the About chip is cleared or that discussion is closed. Sharing a product while a discussion is targeted attaches it as a suggested alternative inside that discussion.
- The thread shows one product conversation at a time. The chips switch which product is open. Other products' messages and the multi-photo basket stay out of that view.
- Opening a chat marks general messages read. Opening a discussion marks that discussion read. Folded discussions keep their unread count.
- Closing the chat hides discussion Close / Reopen until the chat is reopened. Reopening assigns the next ticket number.
- Replace `ChatMockStore` when the API exists. Keep the screens on the same thread, discussion, and message shapes until the contract is known.

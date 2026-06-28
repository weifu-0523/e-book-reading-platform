/// 书籍单元格（卡片 / 列表项）右上方"更多操作"菜单的可选动作。
///
/// 与 [BookContextMenuAction] 区别：
/// - 本枚举对应内联 PopupMenu（单元格角落的"⋮"按钮）。
/// - [BookContextMenuAction] 对应长按弹出的底部 ActionSheet。
enum BookCellAction { read, details, notes, aiGuide, delete }

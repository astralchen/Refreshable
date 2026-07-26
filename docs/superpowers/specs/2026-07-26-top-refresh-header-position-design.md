# 顶部刷新后 Header 位置修复设计

## 问题

网格页面从顶部下拉刷新后，首个 cell 仍然是第一个数据项，但
`GridHeaderView` 已滚出 viewport，页面看起来像从 cell 开始。正常首次进入和顶部刷新结束后
都应完整显示“最近更新”、加载数量、同步状态和筛选栏。

当前顶部刷新使用锁定内容位置的 viewport overlay。它只在拖动阶段根据即时几何锁定
`contentOffset`，刷新 action 中的 `reloadData` 和 layout invalidation 会改变 collection view
几何，但组件没有在刷新生命周期内保存并恢复触发时的边界，因此结束时可能留下偏移后的
位置。现有 UI 测试只断言 header 元素存在，离屏 header 也会通过。

## 目标行为

- 用户从顶部边界下拉触发刷新时，刷新结束仍停留在当前顶部边界，header 完整可见。
- 刷新期间内容尺寸、inset 或布局变化不得把顶部 header 推出 viewport。
- 普通滚动、未达到阈值的拖动以及切换 Tab 返回时，不主动重置滚动位置。
- 行为适用于所有启用 `locksContentOffset` 的 edge overlay，不添加公开 API。
- 不改变 spinner、文案、trigger 距离、action、inset coordinator 或 Demo 数据。

## 方案

在 `EdgeRefreshComponent` 内保存一次刷新生命周期专属的物理边界锚点：

1. 锁定 overlay 的刷新进入 `.refreshing` 时，记录由 coordinator baseline 和当前物理 edge
   计算出的边界 offset。
2. action 期间发生 `contentSize`、bounds、contentInset 或环境变化时，重新按当前 baseline
   计算同一物理边界并恢复对应轴；另一轴保持用户现有位置。
3. `.ending` 收尾完成前最后校正一次边界，然后清除锚点。
4. cancel、disable、detach、replace 和 remove 同样清除锚点，防止旧生命周期影响新组件。
5. 只有从目标边界开始且 `locksContentOffset == true` 的刷新建立锚点；普通滚动不受影响。

这比在 Demo 的 `performRefresh()` 中直接调用 `setContentOffset` 更可靠，因为内容重载只是
触发问题的一种方式，核心组件才拥有 edge、baseline 和刷新 generation 的完整上下文。

## 测试

- 新增真实网格下拉 UI 测试：
  - 首次进入时 header frame 与 collection view viewport 相交。
  - 完成一次真实下拉刷新后，header frame 仍与 viewport 相交。
  - 第一个 cell 仍为原有首项，页面不插入额外状态卡片。
- 核心组件测试覆盖锁定 overlay 在内容尺寸变化后仍保持顶部边界，以及 detach 后不再恢复
  旧锚点。
- 继续运行 `Refreshable-Package` 全量测试和网格刷新、加载更多安全区域相关 UI 测试。

## 非目标

- 不把 header 改为 sticky/pinned。
- 不在每次 `viewWillAppear` 时滚回顶部。
- 不改变用户主动滚动后的 Tab 状态保留行为。
- 不通过 Demo 专用补丁掩盖核心偏移生命周期问题。

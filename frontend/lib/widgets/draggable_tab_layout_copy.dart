import 'package:flutter/material.dart';

enum TabPosition {
  topLeft,
  topRight,
  bottomLeft,
  bottomRight,
  fullScreen,
}

class TabItem {
  final String id;
  final String title;
  final Widget content;
  final IconData icon;
  TabPosition position;
  bool isVisible;

  TabItem({
    required this.id,
    required this.title,
    required this.content,
    required this.icon,
    this.position = TabPosition.fullScreen,
    this.isVisible = true,
  });
}

class DraggableTabLayout extends StatefulWidget {
  final List<TabItem> tabs;
  final Function(String tabId, TabPosition newPosition)? onTabPositionChanged;
  final Function(String tabId)? onTabTapped;

  const DraggableTabLayout({
    super.key,
    required this.tabs,
    this.onTabPositionChanged,
    this.onTabTapped,
  });

  @override
  State<DraggableTabLayout> createState() => _DraggableTabLayoutState();
}

class _DraggableTabLayoutState extends State<DraggableTabLayout>
    with TickerProviderStateMixin {
  String? _draggingTabId;
  TabPosition? _hoveredPosition;
  late AnimationController _animationController;

  // 탭 위치별 그룹화
  final Map<TabPosition, List<TabItem>> _tabsByPosition = {};

  // 활성 탭 ID 추적
  String? _activeTabId;

  // 화면 방향 추적
  bool get isPortrait => MediaQuery.of(context).orientation == Orientation.portrait;

  // 분할선 비율 (0.0 ~ 1.0)
  double _leftHorizontalDividerRatio = 0.5; // 좌측 상하 분할 비율
  double _rightHorizontalDividerRatio = 0.5; // 우측 상하 분할 비율
  double _verticalDividerRatio = 0.5; // 좌우 분할 비율 (통일)

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _organizeTabsByPosition();

    // 첫 번째 탭을 활성화
    if (widget.tabs.isNotEmpty) {
      _activeTabId = widget.tabs.first.id;
    }
  }

  @override
  void didUpdateWidget(DraggableTabLayout oldWidget) {
    super.didUpdateWidget(oldWidget);
    _organizeTabsByPosition();
  }

  void _organizeTabsByPosition() {
    _tabsByPosition.clear();
    for (final tab in widget.tabs) {
      _tabsByPosition.putIfAbsent(tab.position, () => []).add(tab);
    }
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return Stack(
          children: [
            // 메인 레이아웃 그리드
            _buildMainLayout(constraints),

            // 드래그 중인 탭 표시
            if (_draggingTabId != null)
              _buildDragFeedback(),

            // 드롭 영역 인디케이터
            if (_draggingTabId != null)
              _buildDropZones(constraints),
          ],
        );
      },
    );
  }

  Widget _buildMainLayout(BoxConstraints constraints) {
    final fullScreenTabs = _tabsByPosition[TabPosition.fullScreen] ?? [];
    final hasQuadrantTabs = _tabsByPosition[TabPosition.topLeft]?.isNotEmpty == true ||
        _tabsByPosition[TabPosition.topRight]?.isNotEmpty == true ||
        _tabsByPosition[TabPosition.bottomLeft]?.isNotEmpty == true ||
        _tabsByPosition[TabPosition.bottomRight]?.isNotEmpty == true;

    if (fullScreenTabs.isNotEmpty && !hasQuadrantTabs) {
      // 전체 화면 모드만 (4분할 영역에 탭이 없을 때)
      return _buildFullScreenLayout(fullScreenTabs);
    } else if (fullScreenTabs.isNotEmpty && hasQuadrantTabs) {
      // 혼합 모드: 상단 탭 바 + 4분할 레이아웃
      return _buildMixedLayout(fullScreenTabs, constraints);
    } else {
      // 4분할 레이아웃만
      return _buildQuadrantLayout(constraints);
    }
  }

  // 혼합 레이아웃: 상단 탭 바 + 4분할 영역
  Widget _buildMixedLayout(List<TabItem> fullScreenTabs, BoxConstraints constraints) {
    return Column(
      children: [
        // 상단 탭 바 (fullScreen 탭들)
        Container(
          height: 56,
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
          decoration: BoxDecoration(
            color: Colors.grey[100],
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 2,
                offset: const Offset(0, 1),
              ),
            ],
          ),
          child: Row(
            children: fullScreenTabs.map((tab) => Expanded(
              child: _buildFullScreenTabButton(tab),
            )).toList(),
          ),
        ),
        // 4분할 영역
        Expanded(
          child: _buildQuadrantLayout(constraints),
        ),
      ],
    );
  }

  Widget _buildFullScreenLayout(List<TabItem> tabs) {
    return Column(
      children: [
        // 상단 탭 바
        Container(
          height: 56,
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
          decoration: BoxDecoration(
            color: Colors.grey[100],
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 2,
                offset: const Offset(0, 1),
              ),
            ],
          ),
          child: Row(
            children: tabs.map((tab) => Expanded(
              child: _buildFullScreenTabButton(tab),
            )).toList(),
          ),
        ),
        // 탭 컨텐츠
        Expanded(
          child: tabs.isNotEmpty
              ? IndexedStack(
                  index: tabs.indexWhere((tab) => tab.id == _activeTabId).clamp(0, tabs.length - 1),
                  children: tabs.map((tab) => tab.content).toList(),
                )
              : const Center(child: Text('탭이 없습니다')),
        ),
      ],
    );
  }

  // fullScreen 모드의 탭 버튼
  Widget _buildFullScreenTabButton(TabItem tab) {
    final isActive = tab.id == _activeTabId;

    return Draggable<String>(
      data: tab.id,
      onDragStarted: () {
        setState(() {
          _draggingTabId = tab.id;
          _animationController.forward();
        });
      },
      onDragEnd: (_) {
        setState(() {
          _draggingTabId = null;
          _hoveredPosition = null;
          _animationController.reverse();
        });
      },
      feedback: Material(
        elevation: 8,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            color: Theme.of(context).primaryColor,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(tab.icon, size: 18, color: Colors.white),
              const SizedBox(width: 8),
              Text(
                tab.title,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  decoration: TextDecoration.none,
                  fontFamily: 'Roboto',
                ),
              ),
            ],
          ),
        ),
      ),
      childWhenDragging: Opacity(
        opacity: 0.3,
        child: _buildTabButtonContent(tab, isActive),
      ),
      child: InkWell(
        onTap: () {
          setState(() {
            _activeTabId = tab.id;
          });
          widget.onTabTapped?.call(tab.id);
        },
        borderRadius: BorderRadius.circular(8),
        child: _buildTabButtonContent(tab, isActive),
      ),
    );
  }

  Widget _buildTabButtonContent(TabItem tab, bool isActive) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 2),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: isActive
            ? Theme.of(context).primaryColor.withValues(alpha: 0.15)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(8),
        border: isActive ? Border.all(
          color: Theme.of(context).primaryColor.withValues(alpha: 0.3),
          width: 1.5,
        ) : null,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            tab.icon,
            size: 18,
            color: isActive
                ? Theme.of(context).primaryColor
                : Colors.grey[600],
          ),
          const SizedBox(width: 4),
          Flexible(
            child: Text(
              tab.title,
              style: TextStyle(
                fontSize: 13,
                fontWeight: isActive ? FontWeight.w600 : FontWeight.normal,
                color: isActive
                    ? Theme.of(context).primaryColor
                    : Colors.grey[700],
              ),
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
            ),
          ),
          if (isActive) ...[
            const SizedBox(width: 2),
            Icon(
              Icons.more_vert,
              size: 12,
              color: Theme.of(context).primaryColor.withValues(alpha: 0.5),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildQuadrantLayout(BoxConstraints constraints) {
    // 빈 영역 체크 및 확장 로직
    final topLeftTabs = _tabsByPosition[TabPosition.topLeft] ?? [];
    final topRightTabs = _tabsByPosition[TabPosition.topRight] ?? [];
    final bottomLeftTabs = _tabsByPosition[TabPosition.bottomLeft] ?? [];
    final bottomRightTabs = _tabsByPosition[TabPosition.bottomRight] ?? [];

    // 빈 영역 확인
    final hasTopLeft = topLeftTabs.isNotEmpty;
    final hasTopRight = topRightTabs.isNotEmpty;
    final hasBottomLeft = bottomLeftTabs.isNotEmpty;
    final hasBottomRight = bottomRightTabs.isNotEmpty;

    // 기본 4분할 레이아웃 (드래그 가능한 분할선 포함)
    final screenSize = MediaQuery.of(context).size;

    // 상단과 하단에 탭이 있는지 여부
    final showTopVerticalDivider = hasTopLeft && hasTopRight;
    final showBottomVerticalDivider = hasBottomLeft && hasBottomRight;

    // 세로 모드 판단
    final isPortrait = screenSize.height > screenSize.width;

    if (isPortrait) {
      // 세로 모드: 상하 분할선 드래그 시 좌우 영역이 같이 조절

      // 빈 영역 확장 로직 - 단, 모든 탭이 하나의 영역에만 있을 때는 4분할 레이아웃 유지 (드래그 타겟 제공)
      final allTabsInOneArea = (hasTopLeft && !hasTopRight && !hasBottomLeft && !hasBottomRight) ||
                                (!hasTopLeft && hasTopRight && !hasBottomLeft && !hasBottomRight) ||
                                (!hasTopLeft && !hasTopRight && hasBottomLeft && !hasBottomRight) ||
                                (!hasTopLeft && !hasTopRight && !hasBottomLeft && hasBottomRight);

      if (!allTabsInOneArea) {
        // 좌측이 모두 비어있으면 우측만 표시
        if (!hasTopLeft && !hasBottomLeft && (hasTopRight || hasBottomRight)) {
          return _buildQuadrant(
            hasTopRight ? TabPosition.topRight : TabPosition.bottomRight,
            double.infinity,
            double.infinity,
          );
        }

        // 우측이 모두 비어있으면 좌측만 표시
        if (!hasTopRight && !hasBottomRight && (hasTopLeft || hasBottomLeft)) {
          return _buildQuadrant(
            hasTopLeft ? TabPosition.topLeft : TabPosition.bottomLeft,
            double.infinity,
            double.infinity,
          );
        }

        // 상단이 모두 비어있으면 하단만 표시
        if (!hasTopLeft && !hasTopRight && (hasBottomLeft || hasBottomRight)) {
          return _buildQuadrant(
            hasBottomLeft ? TabPosition.bottomLeft : TabPosition.bottomRight,
            double.infinity,
            double.infinity,
          );
        }

        // 하단이 모두 비어있으면 상단만 표시
        if (!hasBottomLeft && !hasBottomRight && (hasTopLeft || hasTopRight)) {
          return _buildQuadrant(
            hasTopLeft ? TabPosition.topLeft : TabPosition.topRight,
            double.infinity,
            double.infinity,
          );
        }
      }

      // 빈 영역 최소화 레이아웃 (빈 영역은 최소 크기로, 구분선은 항상 표시)
      const minEmptySize = 40.0; // 빈 영역의 최소 크기

      return Row(
        children: [
          // 좌측 영역 (좌상단 + 좌하단)
          if (hasTopLeft || hasBottomLeft)
            Expanded(
              flex: (_verticalDividerRatio * 100).round(),
              child: Column(
                children: [
                  // 좌상단
                  if (hasTopLeft)
                    Expanded(
                      flex: (_leftHorizontalDividerRatio * 100).round(),
                      child: _buildQuadrant(
                        TabPosition.topLeft,
                        double.infinity,
                        double.infinity,
                      ),
                    )
                  else
                    SizedBox(
                      height: minEmptySize,
                      child: _buildQuadrant(
                        TabPosition.topLeft,
                        double.infinity,
                        minEmptySize,
                      ),
                    ),
                  // 가로 분할선 (좌우 동시 조절) - 항상 표시
                  if (hasTopLeft || hasBottomLeft)
                    _buildHorizontalDivider(
                      onDrag: (delta) {
                        setState(() {
                          final newRatio = (_leftHorizontalDividerRatio + delta.delta.dy / screenSize.height).clamp(0.1, 0.9);
                          _leftHorizontalDividerRatio = newRatio;
                          _rightHorizontalDividerRatio = newRatio;
                        });
                      },
                    ),
                  // 좌하단
                  if (hasBottomLeft)
                    Expanded(
                      flex: ((1 - _leftHorizontalDividerRatio) * 100).round(),
                      child: _buildQuadrant(
                        TabPosition.bottomLeft,
                        double.infinity,
                        double.infinity,
                      ),
                    )
                  else
                    SizedBox(
                      height: minEmptySize,
                      child: _buildQuadrant(
                        TabPosition.bottomLeft,
                        double.infinity,
                        minEmptySize,
                      ),
                    ),
                ],
              ),
            )
          else
            SizedBox(
              width: minEmptySize,
              child: Column(
                children: [
                  Expanded(
                    child: _buildQuadrant(
                      TabPosition.topLeft,
                      minEmptySize,
                      double.infinity,
                    ),
                  ),
                  _buildHorizontalDivider(
                    onDrag: (delta) {
                      setState(() {
                        final newRatio = (_leftHorizontalDividerRatio + delta.delta.dy / screenSize.height).clamp(0.1, 0.9);
                        _leftHorizontalDividerRatio = newRatio;
                        _rightHorizontalDividerRatio = newRatio;
                      });
                    },
                  ),
                  Expanded(
                    child: _buildQuadrant(
                      TabPosition.bottomLeft,
                      minEmptySize,
                      double.infinity,
                    ),
                  ),
                ],
              ),
            ),
          // 중앙 세로 분할선 - 항상 표시
          _buildVerticalDivider(
            onDrag: (delta) {
              setState(() {
                _verticalDividerRatio = (_verticalDividerRatio + delta.delta.dx / screenSize.width).clamp(0.1, 0.9);
              });
            },
          ),
          // 우측 영역 (우상단 + 우하단)
          if (hasTopRight || hasBottomRight)
            Expanded(
              flex: ((1 - _verticalDividerRatio) * 100).round(),
              child: Column(
                children: [
                  // 우상단
                  if (hasTopRight)
                    Expanded(
                      flex: (_rightHorizontalDividerRatio * 100).round(),
                      child: _buildQuadrant(
                        TabPosition.topRight,
                        double.infinity,
                        double.infinity,
                      ),
                    )
                  else
                    SizedBox(
                      height: minEmptySize,
                      child: _buildQuadrant(
                        TabPosition.topRight,
                        double.infinity,
                        minEmptySize,
                      ),
                    ),
                  // 가로 분할선 (좌우 동시 조절) - 항상 표시
                  if (hasTopRight || hasBottomRight)
                    _buildHorizontalDivider(
                      onDrag: (delta) {
                        setState(() {
                          final newRatio = (_rightHorizontalDividerRatio + delta.delta.dy / screenSize.height).clamp(0.1, 0.9);
                          _leftHorizontalDividerRatio = newRatio;
                          _rightHorizontalDividerRatio = newRatio;
                        });
                      },
                    ),
                  // 우하단
                  if (hasBottomRight)
                    Expanded(
                      flex: ((1 - _rightHorizontalDividerRatio) * 100).round(),
                      child: _buildQuadrant(
                        TabPosition.bottomRight,
                        double.infinity,
                        double.infinity,
                      ),
                    )
                  else
                    SizedBox(
                      height: minEmptySize,
                      child: _buildQuadrant(
                        TabPosition.bottomRight,
                        double.infinity,
                        minEmptySize,
                      ),
                    ),
                ],
              ),
            )
          else
            SizedBox(
              width: minEmptySize,
              child: Column(
                children: [
                  Expanded(
                    child: _buildQuadrant(
                      TabPosition.topRight,
                      minEmptySize,
                      double.infinity,
                    ),
                  ),
                  _buildHorizontalDivider(
                    onDrag: (delta) {
                      setState(() {
                        final newRatio = (_rightHorizontalDividerRatio + delta.delta.dy / screenSize.height).clamp(0.1, 0.9);
                        _leftHorizontalDividerRatio = newRatio;
                        _rightHorizontalDividerRatio = newRatio;
                      });
                    },
                  ),
                  Expanded(
                    child: _buildQuadrant(
                      TabPosition.bottomRight,
                      minEmptySize,
                      double.infinity,
                    ),
                  ),
                ],
              ),
            ),
        ],
      );
    } else {
      // 가로 모드: 빈 영역 최소화 레이아웃
      const minEmptySize = 40.0;

      return Column(
        children: [
          // 상단 영역 (좌상단 + 우상단)
          if (hasTopLeft || hasTopRight)
            Expanded(
              flex: (_leftHorizontalDividerRatio * 100).round(),
              child: Row(
                children: [
                  // 좌상단
                  if (hasTopLeft)
                    Expanded(
                      flex: (_verticalDividerRatio * 100).round(),
                      child: _buildQuadrant(
                        TabPosition.topLeft,
                        double.infinity,
                        double.infinity,
                      ),
                    )
                  else
                    SizedBox(
                      width: minEmptySize,
                      child: _buildQuadrant(
                        TabPosition.topLeft,
                        minEmptySize,
                        double.infinity,
                      ),
                    ),
                  // 세로 분할선 (상하 동시 조절) - 항상 표시
                  if (hasTopLeft || hasTopRight)
                    _buildVerticalDivider(
                      onDrag: (delta) {
                        setState(() {
                          final newRatio = (_verticalDividerRatio + delta.delta.dx / screenSize.width).clamp(0.1, 0.9);
                          _verticalDividerRatio = newRatio;
                          _verticalDividerRatio = newRatio;
                        });
                      },
                    ),
                  // 우상단
                  if (hasTopRight)
                    Expanded(
                      flex: ((1 - _verticalDividerRatio) * 100).round(),
                      child: _buildQuadrant(
                        TabPosition.topRight,
                        double.infinity,
                        double.infinity,
                      ),
                    )
                  else
                    SizedBox(
                      width: minEmptySize,
                      child: _buildQuadrant(
                        TabPosition.topRight,
                        minEmptySize,
                        double.infinity,
                      ),
                    ),
                ],
              ),
            )
          else
            SizedBox(
              height: minEmptySize,
              child: Row(
                children: [
                  Expanded(
                    child: _buildQuadrant(
                      TabPosition.topLeft,
                      double.infinity,
                      minEmptySize,
                    ),
                  ),
                  _buildVerticalDivider(
                    onDrag: (delta) {
                      setState(() {
                        final newRatio = (_verticalDividerRatio + delta.delta.dx / screenSize.width).clamp(0.1, 0.9);
                        _verticalDividerRatio = newRatio;
                        _verticalDividerRatio = newRatio;
                      });
                    },
                  ),
                  Expanded(
                    child: _buildQuadrant(
                      TabPosition.topRight,
                      double.infinity,
                      minEmptySize,
                    ),
                  ),
                ],
              ),
            ),
          // 중앙 가로 분할선 - 항상 표시
          _buildHorizontalDivider(
            onDrag: (delta) {
              setState(() {
                _leftHorizontalDividerRatio = (_leftHorizontalDividerRatio + delta.delta.dy / screenSize.height).clamp(0.1, 0.9);
                _rightHorizontalDividerRatio = _leftHorizontalDividerRatio;
              });
            },
          ),
          // 하단 영역 (좌하단 + 우하단)
          if (hasBottomLeft || hasBottomRight)
            Expanded(
              flex: ((1 - _leftHorizontalDividerRatio) * 100).round(),
              child: Row(
                children: [
                  // 좌하단
                  if (hasBottomLeft)
                    Expanded(
                      flex: (_verticalDividerRatio * 100).round(),
                      child: _buildQuadrant(
                        TabPosition.bottomLeft,
                        double.infinity,
                        double.infinity,
                      ),
                    )
                  else
                    SizedBox(
                      width: minEmptySize,
                      child: _buildQuadrant(
                        TabPosition.bottomLeft,
                        minEmptySize,
                        double.infinity,
                      ),
                    ),
                  // 세로 분할선 (상하 동시 조절) - 항상 표시
                  if (hasBottomLeft || hasBottomRight)
                    _buildVerticalDivider(
                      onDrag: (delta) {
                        setState(() {
                          final newRatio = (_verticalDividerRatio + delta.delta.dx / screenSize.width).clamp(0.1, 0.9);
                          _verticalDividerRatio = newRatio;
                          _verticalDividerRatio = newRatio;
                        });
                      },
                    ),
                  // 우하단
                  if (hasBottomRight)
                    Expanded(
                      flex: ((1 - _verticalDividerRatio) * 100).round(),
                      child: _buildQuadrant(
                        TabPosition.bottomRight,
                        double.infinity,
                        double.infinity,
                      ),
                    )
                  else
                    SizedBox(
                      width: minEmptySize,
                      child: _buildQuadrant(
                        TabPosition.bottomRight,
                        minEmptySize,
                        double.infinity,
                      ),
                    ),
                ],
              ),
            )
          else
            SizedBox(
              height: minEmptySize,
              child: Row(
                children: [
                  Expanded(
                    child: _buildQuadrant(
                      TabPosition.bottomLeft,
                      double.infinity,
                      minEmptySize,
                    ),
                  ),
                  _buildVerticalDivider(
                    onDrag: (delta) {
                      setState(() {
                        final newRatio = (_verticalDividerRatio + delta.delta.dx / screenSize.width).clamp(0.1, 0.9);
                        _verticalDividerRatio = newRatio;
                        _verticalDividerRatio = newRatio;
                      });
                    },
                  ),
                  Expanded(
                    child: _buildQuadrant(
                      TabPosition.bottomRight,
                      double.infinity,
                      minEmptySize,
                    ),
                  ),
                ],
              ),
            ),
        ],
      );
    }
  }

  Widget _buildQuadrant(TabPosition position, double width, double height) {
    final tabs = _tabsByPosition[position] ?? [];

    return Container(
      decoration: BoxDecoration(
        border: Border.all(
          color: _hoveredPosition == position
              ? Theme.of(context).primaryColor
              : Colors.grey.withValues(alpha: 0.3),
          width: _hoveredPosition == position ? 2 : 1,
        ),
      ),
      child: DragTarget<String>(
        onWillAcceptWithDetails: (details) {
          setState(() {
            _hoveredPosition = position;
          });
          return true;
        },
        onLeave: (_) {
          setState(() {
            _hoveredPosition = null;
          });
        },
        onAcceptWithDetails: (details) {
          _handleTabDrop(details.data, position);
        },
        builder: (context, candidateData, rejectedData) {
          if (tabs.isEmpty) {
            return _buildEmptyQuadrant(position);
          }

          return Column(
            children: [
              // 탭 헤더 (항상 표시)
              Container(
                height: 36,
                decoration: BoxDecoration(
                  color: Theme.of(context).cardColor,
                  border: Border(
                    bottom: BorderSide(
                      color: Colors.grey.withValues(alpha: 0.3),
                    ),
                  ),
                ),
                child: Row(
                  children: tabs.map((tab) => Expanded(
                    child: _buildTabHeader(tab, isFullScreen: false),
                  )).toList(),
                ),
              ),
              // 탭 컨텐츠
              Expanded(
                child: tabs.isNotEmpty
                    ? IndexedStack(
                        index: tabs.indexWhere((tab) => tab.id == _activeTabId).clamp(0, tabs.length - 1),
                        children: tabs.map((tab) => tab.content).toList(),
                      )
                    : const SizedBox.shrink(),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildSingleTabContent(TabItem tab) {
    return Stack(
      children: [
        tab.content,
        Positioned(
          top: 8,
          right: 8,
          child: _buildDraggableTabHandle(tab),
        ),
      ],
    );
  }

  Widget _buildTabHeader(TabItem tab, {required bool isFullScreen}) {
    final isActive = tab.id == _activeTabId;
    final isDragging = _draggingTabId == tab.id;

    return Draggable<String>(
      data: tab.id,
      onDragStarted: () {
        setState(() {
          _draggingTabId = tab.id;
          _animationController.forward();
        });
      },
      onDragEnd: (_) {
        setState(() {
          _draggingTabId = null;
          _hoveredPosition = null;
          _animationController.reverse();
        });
      },
      feedback: Material(
        elevation: 12,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                Theme.of(context).primaryColor,
                Theme.of(context).primaryColor.withValues(alpha: 0.8),
              ],
            ),
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Theme.of(context).primaryColor.withValues(alpha: 0.4),
                blurRadius: 8,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(tab.icon, size: 20, color: Colors.white),
              const SizedBox(width: 10),
              Text(
                tab.title,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  decoration: TextDecoration.none,
                ),
              ),
              const SizedBox(width: 8),
              const Icon(
                Icons.open_with,
                size: 16,
                color: Colors.white70,
              ),
            ],
          ),
        ),
      ),
      childWhenDragging: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.grey.withValues(alpha: 0.3),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: Colors.grey.withValues(alpha: 0.5),
            style: BorderStyle.solid,
            width: 2,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              tab.icon,
              size: 16,
              color: Colors.grey.withValues(alpha: 0.6),
            ),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                tab.title,
                style: TextStyle(
                  fontSize: isFullScreen ? 14 : 12,
                  fontWeight: FontWeight.normal,
                  color: Colors.grey.withValues(alpha: 0.6),
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
      child: InkWell(
        onTap: () {
          setState(() {
            _activeTabId = tab.id;
          });
          widget.onTabTapped?.call(tab.id);
        },
        borderRadius: BorderRadius.circular(8),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: isActive
                ? Theme.of(context).primaryColor.withValues(alpha: 0.15)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: isActive
                  ? Theme.of(context).primaryColor.withValues(alpha: 0.3)
                  : Colors.transparent,
              width: 1,
            ),
            boxShadow: isActive ? [
              BoxShadow(
                color: Theme.of(context).primaryColor.withValues(alpha: 0.2),
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ] : null,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              AnimatedScale(
                scale: isActive ? 1.1 : 1.0,
                duration: const Duration(milliseconds: 200),
                child: Icon(
                  tab.icon,
                  size: 16,
                  color: isActive
                      ? Theme.of(context).primaryColor
                      : Colors.grey[600],
                ),
              ),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  tab.title,
                  style: TextStyle(
                    fontSize: isFullScreen ? 14 : 12,
                    fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
                    color: isActive
                        ? Theme.of(context).primaryColor
                        : Colors.grey[700],
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (!isDragging)
                Padding(
                  padding: const EdgeInsets.only(left: 4),
                  child: Icon(
                    Icons.drag_indicator,
                    size: 14,
                    color: isActive
                        ? Theme.of(context).primaryColor.withValues(alpha: 0.7)
                        : Colors.grey.withValues(alpha: 0.5),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDraggableTabHandle(TabItem tab) {
    return Draggable<String>(
      data: tab.id,
      onDragStarted: () {
        setState(() {
          _draggingTabId = tab.id;
          _animationController.forward();
        });
      },
      onDragEnd: (_) {
        setState(() {
          _draggingTabId = null;
          _hoveredPosition = null;
          _animationController.reverse();
        });
      },
      feedback: Material(
        elevation: 8,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Theme.of(context).primaryColor,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(tab.icon, size: 20, color: Colors.white),
        ),
      ),
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(8),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.1),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Icon(
          Icons.drag_indicator,
          size: 20,
          color: Colors.grey[600],
        ),
      ),
    );
  }

  Widget _buildEmptyQuadrant(TabPosition position) {
    final isHovered = _hoveredPosition == position;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      decoration: BoxDecoration(
        gradient: isHovered ? LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Theme.of(context).primaryColor.withValues(alpha: 0.2),
            Theme.of(context).primaryColor.withValues(alpha: 0.1),
          ],
        ) : LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.grey.withValues(alpha: 0.05),
            Colors.grey.withValues(alpha: 0.02),
          ],
        ),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isHovered
              ? Theme.of(context).primaryColor.withValues(alpha: 0.5)
              : Colors.grey.withValues(alpha: 0.2),
          width: isHovered ? 3 : 2,
          style: BorderStyle.solid,
        ),
      ),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            AnimatedScale(
              scale: isHovered ? 1.3 : 1.0,
              duration: const Duration(milliseconds: 200),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: isHovered
                      ? Theme.of(context).primaryColor.withValues(alpha: 0.15)
                      : Colors.grey.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: isHovered
                        ? Theme.of(context).primaryColor.withValues(alpha: 0.4)
                        : Colors.grey.withValues(alpha: 0.3),
                    width: 2,
                    style: BorderStyle.solid,
                  ),
                  boxShadow: isHovered ? [
                    BoxShadow(
                      color: Theme.of(context).primaryColor.withValues(alpha: 0.2),
                      blurRadius: 8,
                      offset: const Offset(0, 4),
                    ),
                  ] : null,
                ),
                child: Icon(
                  Icons.add_box_outlined,
                  size: 56,
                  color: isHovered
                      ? Theme.of(context).primaryColor
                      : Colors.grey[400],
                ),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              _getPositionLabel(position),
              style: TextStyle(
                color: isHovered
                    ? Theme.of(context).primaryColor
                    : Colors.grey[600],
                fontSize: 18,
                fontWeight: isHovered ? FontWeight.bold : FontWeight.w600,
              ),
            ),
            const SizedBox(height: 12),
            AnimatedOpacity(
              opacity: isHovered ? 1.0 : 0.7,
              duration: const Duration(milliseconds: 200),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: isHovered
                      ? Theme.of(context).primaryColor.withValues(alpha: 0.1)
                      : Colors.grey.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: isHovered
                        ? Theme.of(context).primaryColor.withValues(alpha: 0.3)
                        : Colors.grey.withValues(alpha: 0.2),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.touch_app,
                      size: 14,
                      color: isHovered
                          ? Theme.of(context).primaryColor
                          : Colors.grey[500],
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '탭을 여기로 드래그하세요',
                      style: TextStyle(
                        color: isHovered
                            ? Theme.of(context).primaryColor
                            : Colors.grey[500],
                        fontSize: 12,
                        fontWeight: isHovered ? FontWeight.w500 : FontWeight.normal,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _getPositionLabel(TabPosition position) {
    switch (position) {
      case TabPosition.topLeft:
        return '좌상단';
      case TabPosition.topRight:
        return '우상단';
      case TabPosition.bottomLeft:
        return '좌하단';
      case TabPosition.bottomRight:
        return '우하단';
      case TabPosition.fullScreen:
        return '전체화면';
    }
  }

  Widget _buildDragFeedback() {
    return const SizedBox.shrink();
  }

  Widget _buildDropZones(BoxConstraints constraints) {
    if (_tabsByPosition[TabPosition.fullScreen]?.isNotEmpty ?? false) {
      // 전체화면 모드일 때는 4분할 영역 표시
      return _buildQuadrantDropZones(constraints);
    }
    return const SizedBox.shrink();
  }

  Widget _buildQuadrantDropZones(BoxConstraints constraints) {
    return Stack(
      children: [
        // 4분할 드롭 존 오버레이
        Positioned(
          top: 50,
          left: 10,
          child: _buildDropZoneIndicator(TabPosition.topLeft, '좌상단'),
        ),
        Positioned(
          top: 50,
          right: 10,
          child: _buildDropZoneIndicator(TabPosition.topRight, '우상단'),
        ),
        Positioned(
          bottom: 10,
          left: 10,
          child: _buildDropZoneIndicator(TabPosition.bottomLeft, '좌하단'),
        ),
        Positioned(
          bottom: 10,
          right: 10,
          child: _buildDropZoneIndicator(TabPosition.bottomRight, '우하단'),
        ),
      ],
    );
  }

  Widget _buildDropZoneIndicator(TabPosition position, String label) {
    return DragTarget<String>(
      onWillAcceptWithDetails: (details) {
        setState(() {
          _hoveredPosition = position;
        });
        return true;
      },
      onLeave: (_) {
        setState(() {
          _hoveredPosition = null;
        });
      },
      onAcceptWithDetails: (details) {
        _handleTabDrop(details.data, position);
      },
      builder: (context, candidateData, rejectedData) {
        final isHovered = _hoveredPosition == position;

        return AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
          width: isHovered ? 140 : 100,
          height: isHovered ? 90 : 60,
          decoration: BoxDecoration(
            gradient: isHovered ? LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Theme.of(context).primaryColor.withValues(alpha: 0.4),
                Theme.of(context).primaryColor.withValues(alpha: 0.2),
              ],
            ) : LinearGradient(
              colors: [
                Colors.grey.withValues(alpha: 0.2),
                Colors.grey.withValues(alpha: 0.1),
              ],
            ),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isHovered
                  ? Theme.of(context).primaryColor
                  : Colors.grey.withValues(alpha: 0.5),
              width: isHovered ? 3 : 2,
            ),
            boxShadow: isHovered ? [
              BoxShadow(
                color: Theme.of(context).primaryColor.withValues(alpha: 0.3),
                blurRadius: 8,
                offset: const Offset(0, 4),
              ),
            ] : [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.1),
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: AnimatedScale(
            scale: isHovered ? 1.05 : 1.0,
            duration: const Duration(milliseconds: 200),
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  AnimatedRotation(
                    turns: isHovered ? 0.1 : 0.0,
                    duration: const Duration(milliseconds: 200),
                    child: Icon(
                      Icons.apps,
                      size: isHovered ? 28 : 24,
                      color: isHovered
                          ? Theme.of(context).primaryColor
                          : Colors.grey[600],
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    label,
                    style: TextStyle(
                      color: isHovered
                          ? Theme.of(context).primaryColor
                          : Colors.grey[600],
                      fontWeight: isHovered ? FontWeight.bold : FontWeight.w500,
                      fontSize: isHovered ? 14 : 12,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  void _handleTabDrop(String tabId, TabPosition newPosition) {
    setState(() {
      // 탭 찾기
      TabItem? tab;
      TabPosition? oldPosition;
      for (final t in widget.tabs) {
        if (t.id == tabId) {
          tab = t;
          oldPosition = t.position;
          break;
        }
      }

      if (tab != null) {
        // 새 위치가 빈 영역인지 확인 (이동하려는 탭이 동일한 위치에 있는지도 고려)
        final currentTabsInNewPosition = _tabsByPosition[newPosition] ?? [];
        // wasEmpty: 새 위치에 탭이 없거나, 있다면 이동하려는 탭 자신뿐인 경우
        final wasEmpty = currentTabsInNewPosition.isEmpty ||
                         (currentTabsInNewPosition.length == 1 && currentTabsInNewPosition.first.id == tabId);

        // 이전 위치 저장 (로그용)
        final oldPos = tab.position;

        // 이전 위치에서 제거
        _tabsByPosition[tab.position]?.remove(tab);

        // 새 위치로 이동
        tab.position = newPosition;

        // 탭 위치 재구성
        _organizeTabsByPosition();

        // 디버그 로그
        debugPrint('🔄 탭 이동: $tabId ($oldPos → $newPosition), wasEmpty: $wasEmpty');

        // 빈 영역으로 이동한 경우 해당 영역을 확장
        if (wasEmpty) {
          debugPrint('📐 영역 확장: $newPosition');
          _expandAreaForPosition(newPosition);
        } else {
          debugPrint('⚖️ 분할선 비율 초기화: 50/50');
          // 탭이 도킹되면 분할선 비율을 50%로 초기화
          _resetDividerRatios();
        }

        // 콜백 호출
        widget.onTabPositionChanged?.call(tabId, newPosition);
      }

      _hoveredPosition = null;
    });
  }

  // 특정 위치의 영역을 확장
  void _expandAreaForPosition(TabPosition position) {
    // 드롭된 영역을 50% 크기로 확장
    // 좌우 분할: 50/50 (0.5)
    // 상하 분할: 해당 영역만 100% (1.0)

    switch (position) {
      case TabPosition.topLeft:
        // 좌상단을 확대: 좌측 50%, 좌측 내에서 상단 100%
        _verticalDividerRatio = 0.5; // 좌우 50/50
        _leftHorizontalDividerRatio = 1.0; // 좌측 내 상단 100%
        _rightHorizontalDividerRatio = 0.5; // 우측은 50/50
        break;
      case TabPosition.topRight:
        // 우상단을 확대: 우측 50%, 우측 내에서 상단 100%
        _verticalDividerRatio = 0.5; // 좌우 50/50
        _leftHorizontalDividerRatio = 0.5; // 좌측은 50/50
        _rightHorizontalDividerRatio = 1.0; // 우측 내 상단 100%
        break;
      case TabPosition.bottomLeft:
        // 좌하단을 확대: 좌측 50%, 좌측 내에서 상단 50%, 하단 50%
        _verticalDividerRatio = 0.5; // 좌우 50/50
        _leftHorizontalDividerRatio = 0.5; // 좌측 내 상단 50%, 하단 50%
        _rightHorizontalDividerRatio = 0.5; // 우측은 50/50
        break;
      case TabPosition.bottomRight:
        // 우하단을 확대: 전체 4개 영역 동일 비율 (각 25%)
        _verticalDividerRatio = 0.5; // 좌우 50/50
        _leftHorizontalDividerRatio = 0.5; // 좌측 내 상단 50%, 하단 50%
        _rightHorizontalDividerRatio = 0.5; // 우측 내 상단 50%, 하단 50%
        break;
      case TabPosition.fullScreen:
        // 전체 화면은 확장할 필요 없음
        break;
    }
  }

  // 분할선 비율 초기화
  void _resetDividerRatios() {
    _leftHorizontalDividerRatio = 0.5;
    _rightHorizontalDividerRatio = 0.5;
    _verticalDividerRatio = 0.5;
  }

  // 세로 화면에서 확장된 레이아웃
  Widget _buildExpandedPortraitLayout(
    List<TabItem> topTabs,
    List<TabItem> bottomLeftTabs,
    List<TabItem> bottomRightTabs, {
    TabPosition? expandedTop,
    TabPosition? expandedBottom,
  }) {
    final constraints = MediaQuery.of(context).size;
    final halfHeight = constraints.height / 2;

    // 상단이 비어있고 하단만 있는 경우
    if (topTabs.isEmpty && (bottomLeftTabs.isNotEmpty || bottomRightTabs.isNotEmpty)) {
      return Column(
        children: [
          // 하단 영역이 전체 높이를 차지
          Expanded(
            child: Row(
              children: [
                if (bottomLeftTabs.isNotEmpty)
                  Expanded(
                    flex: expandedBottom == TabPosition.bottomLeft || bottomRightTabs.isEmpty ? 1 : 0,
                    child: _buildQuadrant(
                      TabPosition.bottomLeft,
                      expandedBottom == TabPosition.bottomLeft || bottomRightTabs.isEmpty
                          ? constraints.width
                          : constraints.width / 2,
                      constraints.height,
                    ),
                  ),
                if (bottomRightTabs.isNotEmpty)
                  Expanded(
                    flex: expandedBottom == TabPosition.bottomRight || bottomLeftTabs.isEmpty ? 1 : 0,
                    child: _buildQuadrant(
                      TabPosition.bottomRight,
                      expandedBottom == TabPosition.bottomRight || bottomLeftTabs.isEmpty
                          ? constraints.width
                          : constraints.width / 2,
                      constraints.height,
                    ),
                  ),
              ],
            ),
          ),
        ],
      );
    }

    // 하단이 비어있고 상단만 있는 경우
    if (bottomLeftTabs.isEmpty && bottomRightTabs.isEmpty && topTabs.isNotEmpty) {
      return _buildQuadrant(
        expandedTop ?? TabPosition.topLeft,
        constraints.width,
        constraints.height - kToolbarHeight - 48,
      );
    }

    // 상단과 하단 모두 있는 경우
    return Column(
      children: [
        // 상단 영역 (전체 너비로 확장) - 항상 표시
        SizedBox(
          height: topTabs.isNotEmpty ? halfHeight : 0,
          child: topTabs.isNotEmpty
              ? _buildQuadrant(
                  expandedTop ?? TabPosition.topLeft,
                  constraints.width,
                  halfHeight,
                )
              : const SizedBox.shrink(),
        ),
        // 하단 영역 - 항상 표시
        Expanded(
          child: Row(
            children: [
              if (bottomLeftTabs.isNotEmpty)
                Expanded(
                  flex: bottomRightTabs.isEmpty ? 1 : (expandedBottom == TabPosition.bottomLeft ? 2 : 1),
                  child: _buildQuadrant(
                    TabPosition.bottomLeft,
                    bottomRightTabs.isEmpty
                        ? constraints.width
                        : (expandedBottom == TabPosition.bottomLeft
                            ? constraints.width
                            : constraints.width / 2),
                    topTabs.isEmpty ? constraints.height - kToolbarHeight - 48 : halfHeight,
                  ),
                ),
              if (bottomRightTabs.isNotEmpty)
                Expanded(
                  flex: bottomLeftTabs.isEmpty ? 1 : (expandedBottom == TabPosition.bottomRight ? 2 : 1),
                  child: _buildQuadrant(
                    TabPosition.bottomRight,
                    bottomLeftTabs.isEmpty
                        ? constraints.width
                        : (expandedBottom == TabPosition.bottomRight
                            ? constraints.width
                            : constraints.width / 2),
                    topTabs.isEmpty ? constraints.height - kToolbarHeight - 48 : halfHeight,
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }

  // 가로 분할선 위젯
  Widget _buildHorizontalDivider({
    required Function(DragUpdateDetails) onDrag,
  }) {
    return GestureDetector(
      onVerticalDragUpdate: onDrag,
      child: MouseRegion(
        cursor: SystemMouseCursors.resizeUpDown,
        child: Container(
          height: 8,
          color: Colors.transparent,
          child: Center(
            child: Container(
              height: 1,
              color: Colors.grey.withValues(alpha: 0.3),
            ),
          ),
        ),
      ),
    );
  }

  // 세로 분할선 위젯
  Widget _buildVerticalDivider({
    required Function(DragUpdateDetails) onDrag,
  }) {
    return GestureDetector(
      onHorizontalDragUpdate: onDrag,
      child: MouseRegion(
        cursor: SystemMouseCursors.resizeLeftRight,
        child: Container(
          width: 8,
          color: Colors.transparent,
          child: Center(
            child: Container(
              width: 1,
              color: Colors.grey.withValues(alpha: 0.3),
            ),
          ),
        ),
      ),
    );
  }

  // 가로 화면에서 확장된 레이아웃
  Widget _buildExpandedLandscapeLayout(
    List<TabItem> leftTabs,
    List<TabItem> topRightTabs,
    List<TabItem> bottomRightTabs, {
    TabPosition? expandedLeft,
    TabPosition? expandedRight,
  }) {
    final constraints = MediaQuery.of(context).size;
    final halfWidth = constraints.width / 2;
    final fullHeight = constraints.height;

    return Row(
      children: [
        // 좌측 영역 (전체 높이로 확장)
        if (leftTabs.isNotEmpty)
          SizedBox(
            width: halfWidth,
            height: fullHeight,
            child: _buildQuadrant(
              expandedLeft ?? TabPosition.topLeft,
              halfWidth,
              fullHeight,
            ),
          ),
        // 우측 영역
        SizedBox(
          width: halfWidth,
          child: Column(
            children: [
              if (topRightTabs.isNotEmpty)
                SizedBox(
                  height: expandedRight == TabPosition.topRight
                      ? fullHeight
                      : fullHeight / 2,
                  child: _buildQuadrant(
                    TabPosition.topRight,
                    halfWidth,
                    expandedRight == TabPosition.topRight
                        ? fullHeight
                        : fullHeight / 2,
                  ),
                ),
              if (bottomRightTabs.isNotEmpty)
                SizedBox(
                  height: expandedRight == TabPosition.bottomRight
                      ? fullHeight
                      : fullHeight / 2,
                  child: _buildQuadrant(
                    TabPosition.bottomRight,
                    halfWidth,
                    expandedRight == TabPosition.bottomRight
                        ? fullHeight
                        : fullHeight / 2,
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}
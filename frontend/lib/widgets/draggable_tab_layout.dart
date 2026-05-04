import 'package:flutter/material.dart';
import '../l10n/app_localizations.dart';

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
  final Widget? customTabWidget; // 탭 버튼 커스텀 위젯 (제공 시 icon+title 대체)
  TabPosition position;
  bool isVisible;
  final bool isDraggable;

  TabItem({
    required this.id,
    required this.title,
    required this.content,
    required this.icon,
    this.customTabWidget,
    this.position = TabPosition.fullScreen,
    this.isVisible = true,
    this.isDraggable = true,
  });
}

class DraggableTabLayout extends StatefulWidget {
  final List<TabItem> tabs;
  final Function(String tabId, TabPosition newPosition)? onTabPositionChanged;
  final Function(String tabId)? onTabTapped;
  final Function(String tabId)? onTabChanged;
  final String? initialActiveTabId;
  final bool showBottomDock; // deprecated — visibleAreas 사용 권장
  final Set<String> visibleAreas; // 표시할 쿼드런트 집합 (topLeft 항상 포함)

  const DraggableTabLayout({
    super.key,
    required this.tabs,
    this.onTabPositionChanged,
    this.onTabTapped,
    this.onTabChanged,
    this.initialActiveTabId,
    this.showBottomDock = false,
    this.visibleAreas = const {'topLeft'},
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
  Orientation? _previousOrientation;

  // 분할선 비율 (0.0 ~ 1.0) — 4영역 독립 크기 조절
  double _columnWidthRatio = 0.5;    // 좌열/우열 너비 비율
  double _leftHeightRatio = 0.5;     // 좌열 상단(topLeft) 높이 비율
  double _rightHeightRatio = 0.5;    // 우열 상단(topRight) 높이 비율

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _organizeTabsByPosition();

    // 초기 활성 탭 설정 (initialActiveTabId가 있으면 사용, 없으면 첫 번째 탭)
    if (widget.initialActiveTabId != null && widget.tabs.any((tab) => tab.id == widget.initialActiveTabId)) {
      _activeTabId = widget.initialActiveTabId;
      debugPrint('[DraggableTabLayout] 초기 활성 탭 설정: $_activeTabId');
    } else if (widget.tabs.isNotEmpty) {
      _activeTabId = widget.tabs.first.id;
      debugPrint('[DraggableTabLayout] 첫 번째 탭 활성화: $_activeTabId');
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _adjustTabPositionsForOrientation();
  }

  @override
  void didUpdateWidget(DraggableTabLayout oldWidget) {
    super.didUpdateWidget(oldWidget);

    print('[DraggableTabLayout] didUpdateWidget 호출 - 현재 활성 탭: $_activeTabId');

    // 현재 활성 탭이 여전히 존재하는지 확인
    final activeTabStillExists = widget.tabs.any((tab) => tab.id == _activeTabId);
    print('[DraggableTabLayout] 활성 탭 존재 여부: $activeTabStillExists');

    _organizeTabsByPosition();

    // 활성 탭이 사라진 경우에만 첫 번째 탭으로 리셋
    if (!activeTabStillExists && widget.tabs.isNotEmpty) {
      final oldActiveId = _activeTabId;
      _activeTabId = widget.tabs.first.id;
      print('[DraggableTabLayout] 활성 탭 리셋: $oldActiveId -> $_activeTabId');
    } else {
      print('[DraggableTabLayout] 활성 탭 유지: $_activeTabId');
    }

    // 탭 타이틀 등 속성 변경을 즉시 반영
    setState(() {});
  }

  /// 방향 변경 시 탭 위치 매핑
  /// 세로모드 좌하단(bottomLeft) ↔ 가로모드 우상단(topRight)
  /// 세로모드 우상단(topRight) ↔ 가로모드 좌하단(bottomLeft)
  TabPosition _mapPositionForOrientation(TabPosition position, bool toPortrait) {
    if (toPortrait) {
      // 가로 → 세로
      if (position == TabPosition.topRight) return TabPosition.bottomLeft;
      if (position == TabPosition.bottomLeft) return TabPosition.topRight;
    } else {
      // 세로 → 가로
      if (position == TabPosition.bottomLeft) return TabPosition.topRight;
      if (position == TabPosition.topRight) return TabPosition.bottomLeft;
    }
    return position;
  }

  /// 현재 방향에 맞게 모든 탭 위치 조정
  void _adjustTabPositionsForOrientation() {
    final currentOrientation = MediaQuery.of(context).orientation;

    // 방향이 변경되었는지 확인
    if (_previousOrientation != null && _previousOrientation != currentOrientation) {
      final toPortrait = currentOrientation == Orientation.portrait;

      // 변경될 탭들의 정보를 저장
      final List<MapEntry<String, TabPosition>> changedTabs = [];

      // 모든 탭의 위치를 새로운 방향에 맞게 조정
      for (final tab in widget.tabs) {
        final newPosition = _mapPositionForOrientation(tab.position, toPortrait);
        if (newPosition != tab.position) {
          tab.position = newPosition;
          changedTabs.add(MapEntry(tab.id, newPosition));
        }
      }

      // 위치 재정렬
      _organizeTabsByPosition();

      // 현재 빌드 사이클 이후에 콜백 및 setState 실행
      if (mounted && changedTabs.isNotEmpty) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            // 부모 위젯에 변경 사항 알림
            for (final entry in changedTabs) {
              widget.onTabPositionChanged?.call(entry.key, entry.value);
            }
            setState(() {});
          }
        });
      }
    }

    _previousOrientation = currentOrientation;
  }

  void _organizeTabsByPosition() {
    _tabsByPosition.clear();
    for (final tab in widget.tabs) {
      if (!tab.isVisible) continue;
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

    if (fullScreenTabs.isNotEmpty) {
      // 전체 화면 모드일 때
      return _buildFullScreenLayout(fullScreenTabs);
    } else {
      // 4분할 레이아웃
      return _buildQuadrantLayout(constraints);
    }
  }

  Widget _buildFullScreenLayout(List<TabItem> tabs) {
    return Column(
      children: [
        // 탭 헤더
        Container(
          height: 55,
          decoration: BoxDecoration(
            color: Theme.of(context).cardColor,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.1),
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            children: tabs.map((tab) => Expanded(
              child: _buildTabHeader(tab, isFullScreen: true),
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

  Widget _buildQuadrantLayout(BoxConstraints constraints) {
    final screenSize = MediaQuery.of(context).size;
    final areas = widget.visibleAreas;

    final showTopRight = areas.contains('topRight');
    final showBottomLeft = areas.contains('bottomLeft');
    final showBottomRight = areas.contains('bottomRight');
    final showAnyRight = showTopRight || showBottomRight;

    // ── 좌측 컬럼: topLeft + (bottomLeft 있으면 상하 독립 분할) ──
    Widget buildLeftColumn() {
      if (!showBottomLeft) {
        return _buildQuadrant(TabPosition.topLeft, double.infinity, double.infinity);
      }
      return Column(children: [
        Expanded(
          flex: (_leftHeightRatio * 100).round(),
          child: _buildQuadrant(TabPosition.topLeft, double.infinity, double.infinity),
        ),
        _buildHorizontalDivider(onDrag: (d) {
          setState(() {
            _leftHeightRatio =
                (_leftHeightRatio + d.delta.dy / screenSize.height).clamp(0.1, 0.9);
          });
        }),
        Expanded(
          flex: ((1 - _leftHeightRatio) * 100).round(),
          child: _buildQuadrant(TabPosition.bottomLeft, double.infinity, double.infinity),
        ),
      ]);
    }

    // ── 우측 컬럼: topRight + (bottomRight 있으면 상하 독립 분할) ──
    Widget buildRightColumn() {
      if (showTopRight && showBottomRight) {
        return Column(children: [
          Expanded(
            flex: (_rightHeightRatio * 100).round(),
            child: _buildQuadrant(TabPosition.topRight, double.infinity, double.infinity),
          ),
          _buildHorizontalDivider(onDrag: (d) {
            setState(() {
              _rightHeightRatio =
                  (_rightHeightRatio + d.delta.dy / screenSize.height).clamp(0.1, 0.9);
            });
          }),
          Expanded(
            flex: ((1 - _rightHeightRatio) * 100).round(),
            child: _buildQuadrant(TabPosition.bottomRight, double.infinity, double.infinity),
          ),
        ]);
      } else if (showTopRight) {
        return _buildQuadrant(TabPosition.topRight, double.infinity, double.infinity);
      } else {
        return _buildQuadrant(TabPosition.bottomRight, double.infinity, double.infinity);
      }
    }

    // 우측 영역 없으면 좌측 컬럼만
    if (!showAnyRight) {
      return buildLeftColumn();
    }

    // 좌우 컬럼 + 세로 분할선 (세로/가로 모드 공통)
    return Row(children: [
      Expanded(
        flex: (_columnWidthRatio * 100).round(),
        child: buildLeftColumn(),
      ),
      _buildVerticalDivider(onDrag: (d) {
        setState(() {
          _columnWidthRatio =
              (_columnWidthRatio + d.delta.dx / screenSize.width).clamp(0.1, 0.9);
        });
      }),
      Expanded(
        flex: ((1 - _columnWidthRatio) * 100).round(),
        child: buildRightColumn(),
      ),
    ]);
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
                height: 55,
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
    // 전체탭만 있을 때는 항상 선택된 색으로 표시
    final visibleTabs = widget.tabs.where((t) => t.isVisible).toList();
    final isOnlyAllTab = visibleTabs.length == 1 && visibleTabs.first.id == 'all';
    final isActive = tab.id == _activeTabId || (isOnlyAllTab && tab.id == 'all');

    // 탭 클릭 핸들러 (draggable/non-draggable 공통)
    Widget tabContent = InkWell(
      onTap: () {
        debugPrint('[DraggableTabLayout] 탭 클릭: ${tab.id} (${tab.title})');
        setState(() {
          _activeTabId = tab.id;
        });
        debugPrint('[DraggableTabLayout] 활성 탭 변경됨: $_activeTabId');
        widget.onTabTapped?.call(tab.id);
        widget.onTabChanged?.call(tab.id);
      },
      borderRadius: BorderRadius.circular(8),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 8),
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
        child: tab.customTabWidget != null
            ? Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  IconTheme(
                    data: IconThemeData(
                      size: 17,
                      color: isActive
                          ? Theme.of(context).primaryColor
                          : Colors.grey[600],
                    ),
                    child: DefaultTextStyle(
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: isActive ? FontWeight.bold : FontWeight.w600,
                        color: isActive
                            ? Theme.of(context).primaryColor
                            : Colors.grey[700],
                      ),
                      child: tab.customTabWidget!,
                    ),
                  ),
                  if (tab.isDraggable)
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
              )
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  AnimatedScale(
                    scale: isActive ? 1.1 : 1.0,
                    duration: const Duration(milliseconds: 200),
                    child: Icon(
                      tab.icon,
                      size: 19,
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
                        fontSize: isFullScreen ? 17 : 14,
                        fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
                        color: isActive
                            ? Theme.of(context).primaryColor
                            : Colors.grey[700],
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (tab.isDraggable)
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
    );

    // isDraggable == false: Draggable 래퍼 없이 바로 반환
    if (!tab.isDraggable) {
      return tabContent;
    }

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
          child: tab.customTabWidget != null
              ? Row(mainAxisSize: MainAxisSize.min, children: [
                  tab.customTabWidget!,
                  const SizedBox(width: 8),
                  const Icon(Icons.open_with, size: 16, color: Colors.white70),
                ])
              : Row(
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
                    const Icon(Icons.open_with, size: 16, color: Colors.white70),
                  ],
                ),
        ),
      ),
      childWhenDragging: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.grey.withValues(alpha: 0.3),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: Colors.grey.withValues(alpha: 0.5),
            style: BorderStyle.solid,
            width: 2,
          ),
        ),
        child: Icon(
          tab.customTabWidget != null ? Icons.apps : tab.icon,
          size: 16,
          color: Colors.grey.withValues(alpha: 0.6),
        ),
      ),
      child: tabContent,
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
            Theme.of(context).primaryColor.withValues(alpha: 0.1),
            Theme.of(context).primaryColor.withValues(alpha: 0.05),
          ],
        ) : null,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Center(
        child: AnimatedScale(
          scale: isHovered ? 1.2 : 1.0,
          duration: const Duration(milliseconds: 200),
          child: Icon(
            Icons.add_box_outlined,
            size: 14,
            color: isHovered
                ? Theme.of(context).primaryColor
                : Colors.grey[350],
          ),
        ),
      ),
    );
  }

  String _getPositionLabel(BuildContext context, TabPosition position) {
    final l10n = AppLocalizations.of(context);
    switch (position) {
      case TabPosition.topLeft:
        return l10n?.positionTopLeft ?? '좌상단';
      case TabPosition.topRight:
        return l10n?.positionTopRight ?? '우상단';
      case TabPosition.bottomLeft:
        return l10n?.positionBottomLeft ?? '좌하단';
      case TabPosition.bottomRight:
        return l10n?.positionBottomRight ?? '우하단';
      case TabPosition.fullScreen:
        return l10n?.positionTopLeft ?? '전체화면';
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
                      Icons.folder_outlined,
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
      for (final t in widget.tabs) {
        if (t.id == tabId) {
          tab = t;
          break;
        }
      }

      if (tab != null) {
        // 이전 위치에서 제거
        _tabsByPosition[tab.position]?.remove(tab);

        // 새 위치로 이동
        tab.position = newPosition;

        // 탭 위치 재구성
        _organizeTabsByPosition();

        // 탭이 도킹되면 분할선 비율을 50%로 초기화
        _resetDividerRatios();

        // 드롭된 탭을 활성 탭으로 선택
        _activeTabId = tabId;

        // 콜백 호출
        widget.onTabPositionChanged?.call(tabId, newPosition);
      }

      _hoveredPosition = null;
    });
  }

  // 분할선 비율 초기화
  void _resetDividerRatios() {
    _columnWidthRatio = 0.5;
    _leftHeightRatio = 0.5;
    _rightHeightRatio = 0.5;
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

  // 가로 분할선 위젯 (상하 크기 조절)
  Widget _buildHorizontalDivider({
    required Function(DragUpdateDetails) onDrag,
  }) {
    return GestureDetector(
      onVerticalDragUpdate: onDrag,
      behavior: HitTestBehavior.opaque,
      child: MouseRegion(
        cursor: SystemMouseCursors.resizeUpDown,
        child: Container(
          height: 12,
          color: Colors.transparent,
          child: Center(
            child: Container(
              height: 2,
              decoration: BoxDecoration(
                color: Colors.grey[400],
                borderRadius: BorderRadius.circular(1),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.1),
                    blurRadius: 2,
                    offset: const Offset(0, 1),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // 세로 분할선 위젯 (좌우 크기 조절)
  Widget _buildVerticalDivider({
    required Function(DragUpdateDetails) onDrag,
  }) {
    return GestureDetector(
      onHorizontalDragUpdate: onDrag,
      behavior: HitTestBehavior.opaque,
      child: MouseRegion(
        cursor: SystemMouseCursors.resizeLeftRight,
        child: Container(
          width: 12,
          color: Colors.transparent,
          child: Center(
            child: Container(
              width: 2,
              decoration: BoxDecoration(
                color: Colors.grey[400],
                borderRadius: BorderRadius.circular(1),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.1),
                    blurRadius: 2,
                    offset: const Offset(1, 0),
                  ),
                ],
              ),
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
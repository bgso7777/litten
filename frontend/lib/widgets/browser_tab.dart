import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/app_state_provider.dart';
import '../services/bookmark_service.dart';
import '../services/session_service.dart';
import '../services/search_history_service.dart';
import '../widgets/webview/bookmark_widget.dart';
import '../widgets/empty_state.dart';

class BrowserTab extends StatefulWidget {
  const BrowserTab({super.key});

  @override
  State<BrowserTab> createState() => _BrowserTabState();
}

class _BrowserTabState extends State<BrowserTab> {
  WebViewController? _webViewController;
  String _currentUrl = '';
  final TextEditingController _urlController = TextEditingController();
  final BookmarkService _bookmarkService = BookmarkService();
  final SessionService _sessionService = SessionService();
  final SearchHistoryService _searchHistoryService = SearchHistoryService();
  bool _isCurrentUrlBookmarked = false;
  bool _showBookmarks = false;
  bool _isLoading = false;
  String _pageTitle = '';
  List<SearchHistory> _searchHistory = [];

  @override
  void initState() {
    super.initState();
    _loadSearchHistory();
    // 첫 페이지는 항상 검색 기록을 보여줌 - WebView 자동 초기화하지 않음
  }

  Future<void> _loadSearchHistory() async {
    final history = await _searchHistoryService.getSearchHistory();
    setState(() {
      _searchHistory = history;
    });
  }

  @override
  void dispose() {
    _urlController.dispose();
    super.dispose();
  }

  // URL에서 http://, https:// 제거
  String _removeProtocol(String url) {
    return url
        .replaceFirst('https://', '')
        .replaceFirst('http://', '');
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<AppStateProvider>(
      builder: (context, appState, child) {
        return Container(
          color: Theme.of(context).scaffoldBackgroundColor,
          child: Column(
            children: [
              // URL 입력 영역
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
                  border: Border(
                    bottom: BorderSide(color: Theme.of(context).colorScheme.primary.withOpacity(0.2)),
                  ),
                ),
                child: Column(
                  children: [
                    // URL 입력 필드
                    Row(
                      children: [
                        SizedBox(
                          width: MediaQuery.of(context).size.width * 0.50,
                          child: TextField(
                            controller: _urlController,
                            decoration: InputDecoration(
                              hintText: '검색어를 입력하세요...',
                              prefixIcon: const Icon(Icons.search, size: 16),
                              filled: true,
                              fillColor: Colors.white,
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(20),
                                borderSide: BorderSide.none,
                              ),
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 7,
                              ),
                            ),
                            onSubmitted: (url) {
                              if (url.isNotEmpty) {
                                _loadUrl(url);
                              }
                            },
                          ),
                        ),
                        const Spacer(),
                        // 내비게이션 버튼들 (우측 정렬)
                        SizedBox(
                          width: 34,
                          child: IconButton(
                            onPressed: _canGoBack ? _goBack : null,
                            icon: const Icon(Icons.arrow_back, size: 19),
                            tooltip: '뒤로',
                            padding: EdgeInsets.zero,
                          ),
                        ),
                        SizedBox(
                          width: 34,
                          child: IconButton(
                            onPressed: _canGoForward ? _goForward : null,
                            icon: const Icon(Icons.arrow_forward, size: 19),
                            tooltip: '앞으로',
                            padding: EdgeInsets.zero,
                          ),
                        ),
                        SizedBox(
                          width: 34,
                          child: IconButton(
                            onPressed: _reload,
                            icon: const Icon(Icons.refresh, size: 19),
                            tooltip: '새로고침',
                            padding: EdgeInsets.zero,
                          ),
                        ),
                        // 즐겨찾기 버튼
                        SizedBox(
                          width: 34,
                          child: IconButton(
                            onPressed: _toggleBookmark,
                            icon: Icon(
                              _isCurrentUrlBookmarked ? Icons.star : Icons.star_border,
                              color: _isCurrentUrlBookmarked ? Colors.amber : Colors.grey,
                              size: 19,
                            ),
                            tooltip: '즐겨찾기',
                            padding: EdgeInsets.zero,
                          ),
                        ),
                        SizedBox(
                          width: 34,
                          child: IconButton(
                            onPressed: _toggleBookmarksList,
                            icon: Icon(
                              Icons.list,
                              color: _showBookmarks ? Colors.purple.shade700 : Colors.grey,
                              size: 19,
                            ),
                            tooltip: '즐겨찾기 목록',
                            padding: EdgeInsets.zero,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              // WebView 영역, 즐겨찾기 목록, 또는 검색 히스토리
              Expanded(
                child: _showBookmarks
                    ? BookmarkWidget(
                        onBookmarkTap: _onBookmarkSelected,
                        currentUrl: _currentUrl,
                      )
                    : _webViewController != null
                        ? WebViewWidget(controller: _webViewController!)
                        : _searchHistory.isNotEmpty
                            ? _buildSearchHistoryList()
                            : Center(
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      Icons.history,
                                      size: 48,
                                      color: Colors.grey.shade400,
                                    ),
                                    const SizedBox(height: 16),
                                    Text(
                                      '아직 검색 기록이 없습니다',
                                      style: TextStyle(
                                        fontSize: 16,
                                        color: Colors.grey.shade600,
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      '검색창에 검색어를 입력해보세요',
                                      style: TextStyle(
                                        fontSize: 14,
                                        color: Colors.grey.shade500,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
              ),
            ],
          ),
        );
      },
    );
  }

  bool _canGoBack = false;
  bool _canGoForward = false;

  // WebView URL 로드 함수
  void _loadUrl(String url) async {
    debugPrint('🔍 _loadUrl 호출: $url');
    if (url.isEmpty) return;

    // URL 정규화 - http:// 또는 https://가 없으면 추가
    String finalUrl = url;
    bool isSearchQuery = false;

    if (url.startsWith('http://') || url.startsWith('https://')) {
      // 이미 http:// 또는 https://로 시작하는 경우 URL로 간주 (즐겨찾기 등)
      finalUrl = url;
      debugPrint('🔗 완전한 URL: $finalUrl');
    } else {
      // 검색어인지 URL인지 판단
      // URL 패턴: 도메인.확장자 형태 (예: google.com, naver.com, www.example.com)
      // 검색어 패턴: 공백이 있거나 도메인 형태가 아닌 경우
      final urlPattern = RegExp(r'^[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}');

      if (urlPattern.hasMatch(url) && !url.contains(' ')) {
        // URL로 판단
        finalUrl = 'https://$url';
        debugPrint('🔗 URL로 판단: $finalUrl');
      } else {
        // 검색어로 처리
        finalUrl = 'https://www.google.com/search?q=${Uri.encodeComponent(url)}';
        isSearchQuery = true;
        debugPrint('🔍 검색어로 판단: $url');
      }
    }

    debugPrint('🔍 최종 URL: $finalUrl, 검색어 여부: $isSearchQuery');

    // 검색어인 경우 히스토리에 추가
    if (isSearchQuery) {
      await _searchHistoryService.addSearchQuery(url);
      await _loadSearchHistory(); // 히스토리 새로고침
    }

    // 웹 환경에서는 url_launcher 사용
    if (kIsWeb) {
      debugPrint('🌐 웹 환경: URL을 새 탭에서 열기 - $finalUrl');
      final uri = Uri.parse(finalUrl);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
        setState(() {
          _currentUrl = finalUrl;
          _urlController.text = _removeProtocol(finalUrl);
        });
      } else {
        debugPrint('❌ URL을 열 수 없습니다: $finalUrl');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('URL을 열 수 없습니다: $finalUrl')),
          );
        }
      }
      return;
    }

    try {
      if (_webViewController == null) {
        debugPrint('🌐 WebViewController 초기화 시작');
        // WebViewController 초기화
        _webViewController = WebViewController()
          ..setJavaScriptMode(JavaScriptMode.unrestricted)
          ..setBackgroundColor(const Color(0x00000000))
          ..setNavigationDelegate(
            NavigationDelegate(
              onNavigationRequest: (NavigationRequest request) {
                // 모든 네비게이션 요청 허용 (링크 클릭 포함)
                debugPrint('🔗 네비게이션 요청: ${request.url}');
                return NavigationDecision.navigate;
              },
              onProgress: (int progress) {
                // 로딩 진행률 처리
              },
              onPageStarted: (String url) {
                setState(() {
                  _currentUrl = url;
                  _urlController.text = _removeProtocol(url);
                  _isLoading = true;
                });
                _updateBookmarkStatus();
              },
              onPageFinished: (String url) async {
                setState(() {
                  _currentUrl = url;
                  _urlController.text = _removeProtocol(url);
                  _isLoading = false;
                });
                _updateBookmarkStatus();
                _updateNavigationButtons();

                // 페이지 제목 가져오기
                final title = await _getPageTitle();
                if (title != null && title.isNotEmpty) {
                  setState(() {
                    _pageTitle = title;
                  });
                }

                // 세션에 URL 저장
                _sessionService.saveActiveUrl(url);
                // 백그라운드 재생 설정
                _enableBackgroundPlayback();
              },
              onWebResourceError: (WebResourceError error) {
                debugPrint('WebView error: ${error.description}');
                setState(() {
                  _isLoading = false;
                });
              },
            ),
          );
      }

      await _webViewController!.loadRequest(Uri.parse(finalUrl));
      setState(() {
        _currentUrl = finalUrl;
        _urlController.text = finalUrl;
        _isLoading = true;
      });
    } catch (e) {
      debugPrint('[BrowserTab] URL 로드 오류: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  // 즐겨찾기 상태 업데이트
  Future<void> _updateBookmarkStatus() async {
    final isBookmarked = await _bookmarkService.isBookmarked(_currentUrl);
    setState(() {
      _isCurrentUrlBookmarked = isBookmarked;
    });
  }

  // 내비게이션 버튼 상태 업데이트
  void _updateNavigationButtons() async {
    if (_webViewController != null) {
      final canGoBack = await _webViewController!.canGoBack();
      final canGoForward = await _webViewController!.canGoForward();
      setState(() {
        _canGoBack = canGoBack;
        _canGoForward = canGoForward;
      });
    }
  }

  // 즐겨찾기 토글
  void _toggleBookmark() async {
    if (_currentUrl.isEmpty) return;

    final title = await _getPageTitle() ?? _currentUrl;

    if (_isCurrentUrlBookmarked) {
      await _bookmarkService.removeBookmark(_currentUrl);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('즐겨찾기에서 제거되었습니다.'),
            backgroundColor: Colors.orange,
          ),
        );
      }
    } else {
      await _bookmarkService.addBookmark(title, _currentUrl);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('즐겨찾기에 추가되었습니다.'),
            backgroundColor: Colors.green,
          ),
        );
      }
    }
    _updateBookmarkStatus();
  }

  // 즐겨찾기 목록 토글
  void _toggleBookmarksList() {
    setState(() {
      _showBookmarks = !_showBookmarks;
    });
  }

  // 즐겨찾기에서 URL 선택
  void _onBookmarkSelected(String url) {
    debugPrint('⭐ 즐겨찾기 URL 클릭: $url');
    setState(() {
      _showBookmarks = false;
    });
    _loadUrl(url);
  }

  // 뒤로 가기
  void _goBack() async {
    if (_webViewController != null && _canGoBack) {
      await _webViewController!.goBack();
      _updateNavigationButtons();
    }
  }

  // 앞으로 가기
  void _goForward() async {
    if (_webViewController != null && _canGoForward) {
      await _webViewController!.goForward();
      _updateNavigationButtons();
    }
  }

  // 새로고침
  void _reload() async {
    if (_webViewController != null) {
      await _webViewController!.reload();
    }
  }

  // 웹뷰에서 백그라운드 미디어 재생을 활성화합니다
  Future<void> _enableBackgroundPlayback() async {
    if (_webViewController == null) return;

    try {
      // iOS와 Android에서 백그라운드 대응
      await _webViewController!.runJavaScript('''
        (() => {
          // 비디오 요소들에 백그라운드 재생 속성 추가
          const videos = document.querySelectorAll('video');
          videos.forEach(video => {
            video.setAttribute('playsinline', 'true');
            video.setAttribute('webkit-playsinline', 'true');

            // iOS Safari에서 백그라운드 재생 허용
            if (video.webkitEnterFullscreen) {
              video.addEventListener('webkitbeginfullscreen', () => {
                video.style.position = 'fixed';
                video.style.top = '0';
                video.style.left = '0';
                video.style.width = '100%';
                video.style.height = '100%';
                video.style.zIndex = '9999';
              });
            }
          });

          // 오디오 요소들에 백그라운드 재생 속성 추가
          const audios = document.querySelectorAll('audio');
          audios.forEach(audio => {
            audio.setAttribute('preload', 'metadata');
          });

          // Web Audio API를 통한 백그라운드 재생 지원
          if (typeof AudioContext !== 'undefined' || typeof webkitAudioContext !== 'undefined') {
            const AudioContext = window.AudioContext || window.webkitAudioContext;
            if (AudioContext) {
              const audioContext = new AudioContext();
              // 오디오 컨텍스트 상태 확인 및 재생 유지
              if (audioContext.state === 'suspended') {
                audioContext.resume();
              }
            }
          }

          console.log('백그라운드 재생 설정 완료');
        })()
      ''');

      debugPrint('✅ 웹뷰 백그라운드 재생 설정 완료');
    } catch (e) {
      debugPrint('❌ 웹뷰 백그라운드 재생 설정 에러: $e');
    }
  }

  // WebView 초기화
  Future<void> _initializeWebView() async {
    if (_webViewController == null) {
      // 우선순위: 1) 현재 _currentUrl 2) SessionService 활성 URL 3) 기본 URL
      String urlToLoad;
      if (_currentUrl.isNotEmpty) {
        urlToLoad = _currentUrl;
      } else {
        final activeUrl = _sessionService.getCurrentActiveUrl();
        if (activeUrl != null && activeUrl.isNotEmpty) {
          urlToLoad = activeUrl;
          _currentUrl = activeUrl; // 복원된 URL로 _currentUrl 업데이트
        } else {
          urlToLoad = _sessionService.getDefaultUrl();
        }
      }
      debugPrint('🌐 WebView 초기화: $_currentUrl → $urlToLoad');
      _loadUrl(urlToLoad);
    }
  }

  // 페이지 제목 가져오기
  Future<String?> _getPageTitle() async {
    try {
      if (_webViewController != null) {
        return await _webViewController!.getTitle();
      }
    } catch (e) {
      debugPrint('[BrowserTab] 페이지 제목 가져오기 오류: $e');
    }
    return null;
  }

  // 검색 히스토리 리스트 위젯
  Widget _buildSearchHistoryList() {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _searchHistory.length,
      itemBuilder: (context, index) {
        final history = _searchHistory[index];
        final timeAgo = _getTimeAgo(history.timestamp);

        return Card(
          margin: const EdgeInsets.only(bottom: 8),
          child: ListTile(
            leading: Icon(
              Icons.history,
              color: Colors.purple.shade700,
            ),
            title: Text(
              history.query,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
            ),
            subtitle: Text(
              timeAgo,
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey.shade600,
              ),
            ),
            trailing: IconButton(
              icon: const Icon(Icons.close, size: 18),
              onPressed: () async {
                await _searchHistoryService.removeSearchQuery(history.query);
                await _loadSearchHistory();
              },
            ),
            onTap: () {
              _urlController.text = history.query;
              _loadUrl(history.query);
            },
          ),
        );
      },
    );
  }

  // 시간 경과 표시
  String _getTimeAgo(DateTime timestamp) {
    final now = DateTime.now();
    final difference = now.difference(timestamp);

    if (difference.inDays > 0) {
      return '${difference.inDays}일 전';
    } else if (difference.inHours > 0) {
      return '${difference.inHours}시간 전';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes}분 전';
    } else {
      return '방금 전';
    }
  }
}
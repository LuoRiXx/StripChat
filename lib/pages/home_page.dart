import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/model_data.dart';
import '../services/api_service.dart';
import '../services/favorites_service.dart';
import '../services/web_data_fetcher.dart';
import '../widgets/model_card.dart';
import 'live_room_page.dart';
import 'favorites_page.dart';
import 'web_login_page.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int _currentIndex = 0;

  final List<Widget> _pages = const [
    _ModelListTab(),
    FavoritesPage(),
    _ProfileTab(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: _pages,
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          border: Border(
            top: BorderSide(color: Colors.white.withValues(alpha: 0.08)),
          ),
        ),
        child: BottomNavigationBar(
          currentIndex: _currentIndex,
          onTap: (index) => setState(() => _currentIndex = index),
          items: [
            const BottomNavigationBarItem(
              icon: Icon(Icons.home_rounded),
              label: '首页',
            ),
            BottomNavigationBarItem(
              icon: Consumer<FavoritesService>(
                builder: (context, fav, child) {
                  return Badge(
                    isLabelVisible: fav.count > 0,
                    label: Text('${fav.count}'),
                    child: const Icon(Icons.favorite_rounded),
                  );
                },
              ),
              label: '收藏',
            ),
            const BottomNavigationBarItem(
              icon: Icon(Icons.person_rounded),
              label: '我的',
            ),
          ],
        ),
      ),
    );
  }
}

class _ModelListTab extends StatefulWidget {
  const _ModelListTab();

  @override
  State<_ModelListTab> createState() => _ModelListTabState();
}

class _ModelListTabState extends State<_ModelListTab>
    with WidgetsBindingObserver {
  final ApiService _api = ApiService();
  List<ModelData> _models = [];
  bool _isLoading = true;
  bool _isLoadingMore = false;
  bool _isRefreshing = false;
  int _offset = 0;
  final int _limit = 60;
  String _currentTag = 'girls';
  String _sortBy = 'recommendedScore';
  Timer? _refreshTimer;
  final ScrollController _scrollController = ScrollController();
  final TextEditingController _searchController = TextEditingController();

  final List<Map<String, String>> _tags = [
    {'label': '🔥 热门', 'value': 'girls', 'sort': 'viewersCount'},
    {'label': '女生', 'value': 'girls', 'sort': 'recommendedScore'},
    {'label': '男生', 'value': 'guys', 'sort': 'recommendedScore'},
    {'label': '情侣', 'value': 'couples', 'sort': 'recommendedScore'},
    {'label': '变性', 'value': 'trans', 'sort': 'recommendedScore'},
    {'label': '新人', 'value': 'girls', 'sort': 'isNew'},
  ];
  int _selectedTagIndex = 1;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _scrollController.addListener(_onScroll);
    _loadModels();
    // 每30秒后台静默刷新一次
    _refreshTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      _silentRefresh();
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _silentRefresh();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _refreshTimer?.cancel();
    _scrollController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 300) {
      _loadMore();
    }
  }

  Future<void> _loadModels() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _offset = 0;
    });

    final models = await _api.getModels(
      limit: _limit,
      offset: 0,
      primaryTag: _currentTag,
      sortBy: _sortBy,
    );

    if (mounted) {
      setState(() {
        _models = models;
        _isLoading = false;
        _offset = _limit;
      });
    }
  }

  Future<void> _silentRefresh() async {
    if (_isRefreshing || _searchController.text.isNotEmpty) return;
    _isRefreshing = true;
    final models = await _api.getModels(
      limit: _limit,
      offset: 0,
      primaryTag: _currentTag,
      sortBy: _sortBy,
    );
    if (mounted && models.isNotEmpty) {
      setState(() {
        _models = models;
        _offset = _limit;
      });
    }
    _isRefreshing = false;
  }

  Future<void> _loadMore() async {
    if (_isLoadingMore || _searchController.text.isNotEmpty) return;
    setState(() => _isLoadingMore = true);

    final models = await _api.getModels(
      limit: _limit,
      offset: _offset,
      primaryTag: _currentTag,
      sortBy: _sortBy,
    );

    if (mounted) {
      setState(() {
        // 去重
        final existingIds = _models.map((m) => m.id).toSet();
        _models.addAll(models.where((m) => !existingIds.contains(m.id)));
        _offset += _limit;
        _isLoadingMore = false;
      });
    }
  }

  Future<void> _search(String query) async {
    if (query.isEmpty) {
      _loadModels();
      return;
    }
    setState(() => _isLoading = true);
    final models = await _api.searchModels(query);
    if (mounted) {
      setState(() {
        _models = models;
        _isLoading = false;
      });
    }
  }

  void _navigateToLiveRoom(ModelData model) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => LiveRoomPage(model: model),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Column(
        children: [
          // Search bar + status indicator
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _searchController,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      hintText: '搜索主播...',
                      hintStyle:
                          TextStyle(color: Colors.white.withValues(alpha: 0.5)),
                      prefixIcon: const Icon(Icons.search,
                          color: Color(0xFFFF4081)),
                      suffixIcon: _searchController.text.isNotEmpty
                          ? IconButton(
                              icon:
                                  const Icon(Icons.clear, color: Colors.grey),
                              onPressed: () {
                                _searchController.clear();
                                _loadModels();
                              },
                            )
                          : null,
                      filled: true,
                      fillColor: const Color(0xFF1E1E2E),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(24),
                        borderSide: BorderSide.none,
                      ),
                      contentPadding:
                          const EdgeInsets.symmetric(vertical: 0),
                    ),
                    onSubmitted: _search,
                  ),
                ),
                Consumer<WebDataFetcher>(
                  builder: (context, fetcher, _) {
                    return Padding(
                      padding: const EdgeInsets.only(left: 8),
                      child: Container(
                        width: 10,
                        height: 10,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: fetcher.isReady
                              ? Colors.greenAccent
                              : Colors.orangeAccent,
                          boxShadow: [
                            BoxShadow(
                              color: (fetcher.isReady
                                      ? Colors.greenAccent
                                      : Colors.orangeAccent)
                                  .withValues(alpha: 0.6),
                              blurRadius: 6,
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
          // Tags
          SizedBox(
            height: 40,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              itemCount: _tags.length,
              itemBuilder: (context, index) {
                final tag = _tags[index];
                final isSelected = _selectedTagIndex == index;
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: ChoiceChip(
                    label: Text(tag['label']!),
                    selected: isSelected,
                    selectedColor: const Color(0xFFFF4081),
                    backgroundColor: const Color(0xFF1E1E2E),
                    labelStyle: TextStyle(
                      color: isSelected ? Colors.white : Colors.white70,
                      fontSize: 13,
                    ),
                    onSelected: (selected) {
                      setState(() {
                        _selectedTagIndex = index;
                        _currentTag = tag['value']!;
                        _sortBy = tag['sort']!;
                      });
                      _loadModels();
                    },
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 8),
          // Model grid
          Expanded(
            child: _isLoading
                ? _buildSkeletonGrid()
                : _models.isEmpty
                    ? _buildEmptyView()
                    : RefreshIndicator(
                        onRefresh: _loadModels,
                        color: const Color(0xFFFF4081),
                        backgroundColor: const Color(0xFF1E1E2E),
                        child: GridView.builder(
                          controller: _scrollController,
                          padding: const EdgeInsets.all(8),
                          gridDelegate:
                              const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 2,
                            childAspectRatio: 0.72,
                            crossAxisSpacing: 8,
                            mainAxisSpacing: 8,
                          ),
                          itemCount:
                              _models.length + (_isLoadingMore ? 2 : 0),
                          itemBuilder: (context, index) {
                            if (index >= _models.length) {
                              return _buildSkeletonCard();
                            }
                            return ModelCard(
                              model: _models[index],
                              onTap: () =>
                                  _navigateToLiveRoom(_models[index]),
                            );
                          },
                        ),
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildSkeletonGrid() {
    return GridView.builder(
      padding: const EdgeInsets.all(8),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        childAspectRatio: 0.72,
        crossAxisSpacing: 8,
        mainAxisSpacing: 8,
      ),
      itemCount: 8,
      itemBuilder: (context, index) => _buildSkeletonCard(),
    );
  }

  Widget _buildSkeletonCard() {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E2E),
        borderRadius: BorderRadius.circular(12),
      ),
      child: const Center(
        child: SizedBox(
          width: 20,
          height: 20,
          child: CircularProgressIndicator(
            color: Color(0xFFFF4081),
            strokeWidth: 2,
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyView() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.live_tv_outlined,
            size: 64,
            color: Colors.white.withValues(alpha: 0.3),
          ),
          const SizedBox(height: 16),
          Text(
            '暂无直播',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.5),
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: _loadModels,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFFF4081),
            ),
            child: const Text('刷新'),
          ),
        ],
      ),
    );
  }
}

class _ProfileTab extends StatefulWidget {
  const _ProfileTab();

  @override
  State<_ProfileTab> createState() => _ProfileTabState();
}

class _ProfileTabState extends State<_ProfileTab> {
  bool _isLoggedIn = false;
  String _username = '';
  bool _isChecking = true;

  @override
  void initState() {
    super.initState();
    _checkLoginStatus();
  }

  Future<void> _checkLoginStatus() async {
    if (!mounted) return;
    setState(() => _isChecking = true);

    final fetcher = WebDataFetcher();
    if (!fetcher.isReady) {
      await fetcher.waitReady(timeout: const Duration(seconds: 10));
    }

    final user = await fetcher.getCurrentUser();
    if (!mounted) return;
    setState(() {
      _isLoggedIn = user != null && (user['id'] != null);
      _username = (user?['username'] ?? '').toString();
      _isChecking = false;
    });
  }

  Future<void> _openWebLogin() async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const WebLoginPage(),
      ),
    );
    await Future.delayed(const Duration(milliseconds: 500));
    if (mounted) _checkLoginStatus();
  }

  Future<void> _logoutWeb() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E2E),
        title: const Text('退出登录',
            style: TextStyle(color: Colors.white)),
        content: const Text('确定要退出登录吗？',
            style: TextStyle(color: Colors.white70)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style:
                TextButton.styleFrom(foregroundColor: Colors.redAccent),
            child: const Text('退出'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    final fetcher = WebDataFetcher();
    await fetcher.controller?.runJavaScript('''
      fetch('/api/front/v3/auth/logout', {method: 'POST', credentials: 'include'})
        .catch(function(){});
      document.cookie.split(';').forEach(function(c){
        document.cookie = c.replace(/^ +/, '').replace(/=.*/, '=;expires=' + new Date().toUTCString() + ';path=/');
      });
    ''');
    await fetcher.reloadSession();
    if (mounted) _checkLoginStatus();
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            const SizedBox(height: 40),
            CircleAvatar(
              radius: 50,
              backgroundColor: const Color(0xFF2A2A3E),
              child: _isChecking
                  ? const CircularProgressIndicator(color: Color(0xFFFF4081))
                  : Icon(
                      _isLoggedIn ? Icons.person : Icons.person_outline,
                      size: 50,
                      color: const Color(0xFFFF4081),
                    ),
            ),
            const SizedBox(height: 16),
            Text(
              _isChecking
                  ? '检查登录状态...'
                  : (_isLoggedIn
                      ? (_username.isNotEmpty ? _username : '已登录')
                      : '未登录'),
              style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _isLoggedIn ? '尽情享受直播吧 ✨' : '点击下方按钮通过网页登录',
              style: TextStyle(
                fontSize: 14,
                color: Colors.white.withValues(alpha: 0.6),
              ),
            ),
            const SizedBox(height: 32),
            if (!_isLoggedIn)
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton.icon(
                  onPressed: _openWebLogin,
                  icon: const Icon(Icons.login),
                  label: const Text('登录 / 注册',
                      style: TextStyle(fontSize: 16)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFFF4081),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: OutlinedButton.icon(
                onPressed: _checkLoginStatus,
                icon: const Icon(Icons.refresh),
                label: const Text('刷新登录状态',
                    style: TextStyle(fontSize: 16)),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.white70,
                  side: BorderSide(
                    color: Colors.white.withValues(alpha: 0.2),
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
            const Spacer(),
            if (_isLoggedIn)
              SizedBox(
                width: double.infinity,
                height: 50,
                child: OutlinedButton.icon(
                  onPressed: _logoutWeb,
                  icon: const Icon(Icons.logout),
                  label:
                      const Text('退出登录', style: TextStyle(fontSize: 16)),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.redAccent,
                    side: const BorderSide(color: Colors.redAccent),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }
}

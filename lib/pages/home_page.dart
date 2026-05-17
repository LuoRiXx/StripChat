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

class _PrimaryTag {
  final String label;
  final String value;
  const _PrimaryTag(this.label, this.value);
}

class _ModelListTab extends StatefulWidget {
  const _ModelListTab();

  @override
  State<_ModelListTab> createState() => _ModelListTabState();
}

class _ModelListTabState extends State<_ModelListTab>
    with WidgetsBindingObserver, SingleTickerProviderStateMixin {
  final ApiService _api = ApiService();
  List<ModelBlock> _blocks = [];
  List<ModelData> _searchResults = [];
  bool _isSearching = false;
  bool _isLoading = true;
  bool _isRefreshing = false;
  Timer? _refreshTimer;

  final TextEditingController _searchController = TextEditingController();

  static const List<_PrimaryTag> _primaryTags = [
    _PrimaryTag('女主播', 'girls'),
    _PrimaryTag('情侣', 'couples'),
    _PrimaryTag('男主播', 'guys'),
    _PrimaryTag('变性', 'trans'),
  ];
  late TabController _tabController;
  String _currentTag = 'girls';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _tabController = TabController(length: _primaryTags.length, vsync: this);
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging) return;
      final newTag = _primaryTags[_tabController.index].value;
      if (newTag != _currentTag) {
        setState(() => _currentTag = newTag);
        _loadBlocks();
      }
    });
    _loadBlocks();
    _refreshTimer = Timer.periodic(const Duration(seconds: 45), (_) {
      _silentRefresh();
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _silentRefresh();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _refreshTimer?.cancel();
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadBlocks() async {
    if (!mounted) return;
    setState(() => _isLoading = true);
    final blocks = await _api.getModelBlocks(primaryTag: _currentTag);
    if (mounted) {
      setState(() {
        _blocks = blocks;
        _isLoading = false;
      });
    }
  }

  Future<void> _silentRefresh() async {
    if (_isRefreshing || _isSearching) return;
    _isRefreshing = true;
    final blocks = await _api.getModelBlocks(primaryTag: _currentTag);
    if (mounted && blocks.isNotEmpty) {
      setState(() => _blocks = blocks);
    }
    _isRefreshing = false;
  }

  Future<void> _search(String query) async {
    if (query.isEmpty) {
      setState(() {
        _isSearching = false;
        _searchResults = [];
      });
      return;
    }
    setState(() {
      _isSearching = true;
      _isLoading = true;
    });
    final results = await _api.searchModels(query);
    if (mounted) {
      setState(() {
        _searchResults = results;
        _isLoading = false;
      });
    }
  }

  List<ModelData> _allModelsInOrder() {
    final seen = <int>{};
    final out = <ModelData>[];
    for (final block in _blocks) {
      for (final m in block.models) {
        if (seen.add(m.id)) out.add(m);
      }
    }
    return out;
  }

  void _openLiveRoom(ModelData model, List<ModelData> playlist) {
    final idx = playlist.indexWhere((m) => m.id == model.id);
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => LiveRoomPage(
          model: model,
          playlist: playlist,
          startIndex: idx < 0 ? 0 : idx,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Column(
        children: [
          _buildSearchBar(),
          _buildPrimaryTabBar(),
          const SizedBox(height: 4),
          Expanded(
            child: _isLoading
                ? const Center(
                    child: CircularProgressIndicator(color: Color(0xFFFF4081)),
                  )
                : _isSearching
                    ? _buildSearchResultsGrid()
                    : _buildBlocksList(),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchBar() {
    return Padding(
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
                prefixIcon:
                    const Icon(Icons.search, color: Color(0xFFFF4081)),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear, color: Colors.grey),
                        onPressed: () {
                          _searchController.clear();
                          _search('');
                        },
                      )
                    : null,
                filled: true,
                fillColor: const Color(0xFF1E1E2E),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(vertical: 0),
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
    );
  }

  Widget _buildPrimaryTabBar() {
    return Container(
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: Colors.white.withValues(alpha: 0.08)),
        ),
      ),
      child: TabBar(
        controller: _tabController,
        isScrollable: false,
        indicatorColor: const Color(0xFFFF4081),
        indicatorWeight: 3,
        labelColor: Colors.white,
        unselectedLabelColor: Colors.white60,
        labelStyle:
            const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
        unselectedLabelStyle: const TextStyle(fontSize: 15),
        tabs: _primaryTags.map((t) => Tab(text: t.label)).toList(),
      ),
    );
  }

  Widget _buildBlocksList() {
    if (_blocks.isEmpty) return _buildEmptyView();
    final allModels = _allModelsInOrder();
    return RefreshIndicator(
      onRefresh: _loadBlocks,
      color: const Color(0xFFFF4081),
      backgroundColor: const Color(0xFF1E1E2E),
      child: ListView.builder(
        padding: const EdgeInsets.only(top: 8, bottom: 16),
        itemCount: _blocks.length,
        itemBuilder: (context, index) {
          final block = _blocks[index];
          return _BlockSection(
            block: block,
            onTapModel: (m) => _openLiveRoom(m, allModels),
          );
        },
      ),
    );
  }

  Widget _buildSearchResultsGrid() {
    if (_searchResults.isEmpty) return _buildEmptyView();
    return GridView.builder(
      padding: const EdgeInsets.all(8),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        childAspectRatio: 0.72,
        crossAxisSpacing: 8,
        mainAxisSpacing: 8,
      ),
      itemCount: _searchResults.length,
      itemBuilder: (context, index) {
        return ModelCard(
          model: _searchResults[index],
          onTap: () => _openLiveRoom(_searchResults[index], _searchResults),
        );
      },
    );
  }

  Widget _buildEmptyView() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.live_tv_outlined,
              size: 64, color: Colors.white.withValues(alpha: 0.3)),
          const SizedBox(height: 16),
          Text('暂无直播',
              style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.5), fontSize: 16)),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: _loadBlocks,
            style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFFF4081)),
            child: const Text('刷新'),
          ),
        ],
      ),
    );
  }
}

class _BlockSection extends StatelessWidget {
  final ModelBlock block;
  final void Function(ModelData) onTapModel;

  const _BlockSection({required this.block, required this.onTapModel});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: Row(
              children: [
                Container(
                  width: 4,
                  height: 18,
                  decoration: BoxDecoration(
                    color: const Color(0xFFFF4081),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    block.title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                Text(
                  '${block.models.length} 位',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.5),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          SizedBox(
            height: 220,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              itemCount: block.models.length,
              itemBuilder: (context, idx) {
                final model = block.models[idx];
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: SizedBox(
                    width: 160,
                    child: ModelCard(
                      model: model,
                      onTap: () => onTapModel(model),
                    ),
                  ),
                );
              },
            ),
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
      MaterialPageRoute(builder: (context) => const WebLoginPage()),
    );
    await Future.delayed(const Duration(milliseconds: 500));
    if (mounted) _checkLoginStatus();
  }

  Future<void> _logoutWeb() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E2E),
        title: const Text('退出登录', style: TextStyle(color: Colors.white)),
        content: const Text('确定要退出登录吗？',
            style: TextStyle(color: Colors.white70)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.redAccent),
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

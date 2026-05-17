import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/model_data.dart';
import '../services/api_service.dart';
import '../services/auth_service.dart';
import '../services/favorites_service.dart';
import '../widgets/model_card.dart';
import 'live_room_page.dart';
import 'favorites_page.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int _currentIndex = 0;
  final List<Widget> _pages = [];

  @override
  void initState() {
    super.initState();
    _pages.addAll([
      const _ModelListTab(),
      const FavoritesPage(),
      const _ProfileTab(),
    ]);
  }

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
            top: BorderSide(color: Colors.white.withOpacity(0.1)),
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

class _ModelListTabState extends State<_ModelListTab> {
  final ApiService _api = ApiService();
  List<ModelData> _models = [];
  bool _isLoading = true;
  bool _isLoadingMore = false;
  int _offset = 0;
  final int _limit = 50;
  String _currentTag = 'girls';
  String _sortBy = 'recommendedScore';
  final ScrollController _scrollController = ScrollController();
  final TextEditingController _searchController = TextEditingController();

  final List<Map<String, String>> _tags = [
    {'label': '女生', 'value': 'girls'},
    {'label': '男生', 'value': 'guys'},
    {'label': '情侣', 'value': 'couples'},
    {'label': '变性', 'value': 'trans'},
    {'label': '热门', 'value': 'girls'},
  ];

  @override
  void initState() {
    super.initState();
    _loadModels();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      _loadMore();
    }
  }

  Future<void> _loadModels() async {
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

  Future<void> _loadMore() async {
    if (_isLoadingMore) return;
    setState(() => _isLoadingMore = true);

    final models = await _api.getModels(
      limit: _limit,
      offset: _offset,
      primaryTag: _currentTag,
      sortBy: _sortBy,
    );

    if (mounted) {
      setState(() {
        _models.addAll(models);
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
          // Search bar
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: TextField(
              controller: _searchController,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: '搜索主播...',
                hintStyle: TextStyle(color: Colors.white.withOpacity(0.5)),
                prefixIcon: const Icon(Icons.search, color: Color(0xFFFF4081)),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear, color: Colors.grey),
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
                contentPadding: const EdgeInsets.symmetric(vertical: 0),
              ),
              onSubmitted: _search,
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
                final isSelected = _currentTag == tag['value'] &&
                    (index != 4 || _sortBy == 'viewers');
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
                        if (index == 4) {
                          _sortBy = 'viewersCount';
                          _currentTag = 'girls';
                        } else {
                          _currentTag = tag['value']!;
                          _sortBy = 'recommendedScore';
                        }
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
                ? const Center(
                    child: CircularProgressIndicator(
                      color: Color(0xFFFF4081),
                    ),
                  )
                : _models.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.live_tv_outlined,
                              size: 64,
                              color: Colors.white.withOpacity(0.3),
                            ),
                            const SizedBox(height: 16),
                            Text(
                              '暂无直播',
                              style: TextStyle(
                                color: Colors.white.withOpacity(0.5),
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
                      )
                    : RefreshIndicator(
                        onRefresh: _loadModels,
                        color: const Color(0xFFFF4081),
                        child: GridView.builder(
                          controller: _scrollController,
                          padding: const EdgeInsets.all(8),
                          gridDelegate:
                              const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 2,
                            childAspectRatio: 0.75,
                            crossAxisSpacing: 8,
                            mainAxisSpacing: 8,
                          ),
                          itemCount: _models.length + (_isLoadingMore ? 1 : 0),
                          itemBuilder: (context, index) {
                            if (index >= _models.length) {
                              return const Center(
                                child: CircularProgressIndicator(
                                  color: Color(0xFFFF4081),
                                ),
                              );
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
}

class _ProfileTab extends StatelessWidget {
  const _ProfileTab();

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthService>();

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            const SizedBox(height: 40),
            CircleAvatar(
              radius: 50,
              backgroundColor: const Color(0xFF2A2A3E),
              child: Text(
                auth.username.isNotEmpty
                    ? auth.username[0].toUpperCase()
                    : '?',
                style: const TextStyle(
                  fontSize: 36,
                  color: Color(0xFFFF4081),
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              auth.username,
              style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'ID: ${auth.userId}',
              style: TextStyle(
                fontSize: 14,
                color: Colors.white.withOpacity(0.6),
              ),
            ),
            const Spacer(),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: OutlinedButton.icon(
                onPressed: () async {
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
                          style: TextButton.styleFrom(
                            foregroundColor: Colors.redAccent,
                          ),
                          child: const Text('退出'),
                        ),
                      ],
                    ),
                  );
                  if (confirmed == true) {
                    await context.read<AuthService>().logout();
                  }
                },
                icon: const Icon(Icons.logout),
                label: const Text('退出登录', style: TextStyle(fontSize: 16)),
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

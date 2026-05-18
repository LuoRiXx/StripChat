import 'package:flutter/material.dart';
import '../models/model_data.dart';
import '../services/api_service.dart';
import '../widgets/model_card.dart';
import 'live_room_page.dart';

class CategoryDetailPage extends StatefulWidget {
  final String title;
  final String primaryTag;
  final List<ModelData> initialModels;

  const CategoryDetailPage({
    super.key,
    required this.title,
    this.primaryTag = 'girls',
    this.initialModels = const [],
  });

  @override
  State<CategoryDetailPage> createState() => _CategoryDetailPageState();
}

class _CategoryDetailPageState extends State<CategoryDetailPage> {
  final ApiService _api = ApiService();
  final ScrollController _scrollController = ScrollController();
  List<ModelData> _models = [];
  bool _isLoading = false;
  bool _hasMore = true;
  int _offset = 0;
  static const int _pageSize = 30;

  @override
  void initState() {
    super.initState();
    _models = List.from(widget.initialModels);
    _offset = _models.length;
    if (_models.isEmpty) {
      _loadMore();
    }
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 300) {
      _loadMore();
    }
  }

  Future<void> _loadMore() async {
    if (_isLoading || !_hasMore) return;
    setState(() => _isLoading = true);

    final newModels = await _api.getModels(
      limit: _pageSize,
      offset: _offset,
      primaryTag: widget.primaryTag,
    );

    if (mounted) {
      setState(() {
        if (newModels.isEmpty || newModels.length < _pageSize) {
          _hasMore = false;
        }
        // 去重
        final existingIds = _models.map((m) => m.id).toSet();
        final unique = newModels.where((m) => !existingIds.contains(m.id)).toList();
        _models.addAll(unique);
        _offset = _models.length;
        _isLoading = false;
      });
    }
  }

  Future<void> _refresh() async {
    setState(() {
      _models.clear();
      _offset = 0;
      _hasMore = true;
    });
    await _loadMore();
  }

  void _openLiveRoom(ModelData model) {
    final idx = _models.indexWhere((m) => m.id == model.id);
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => LiveRoomPage(
          model: model,
          playlist: _models,
          startIndex: idx < 0 ? 0 : idx,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1A1A2E),
        title: Text(
          widget.title,
          style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _refresh,
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _refresh,
        color: const Color(0xFFFF4081),
        backgroundColor: const Color(0xFF1E1E2E),
        child: _models.isEmpty && _isLoading
            ? const Center(
                child: CircularProgressIndicator(color: Color(0xFFFF4081)),
              )
            : _models.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.live_tv_outlined,
                            size: 48,
                            color: Colors.white.withValues(alpha: 0.3)),
                        const SizedBox(height: 12),
                        Text(
                          '暂无主播',
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.5),
                          ),
                        ),
                      ],
                    ),
                  )
                : GridView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.all(8),
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      childAspectRatio: 0.72,
                      crossAxisSpacing: 8,
                      mainAxisSpacing: 8,
                    ),
                    itemCount: _models.length + (_hasMore ? 1 : 0),
                    itemBuilder: (context, index) {
                      if (index >= _models.length) {
                        return const Center(
                          child: Padding(
                            padding: EdgeInsets.all(16),
                            child: CircularProgressIndicator(
                              color: Color(0xFFFF4081),
                              strokeWidth: 2,
                            ),
                          ),
                        );
                      }
                      return ModelCard(
                        model: _models[index],
                        onTap: () => _openLiveRoom(_models[index]),
                      );
                    },
                  ),
      ),
    );
  }
}

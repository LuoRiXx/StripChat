import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/model_data.dart';
import '../services/favorites_service.dart';
import '../widgets/model_card.dart';
import 'live_room_page.dart';

class FavoritesPage extends StatefulWidget {
  const FavoritesPage({super.key});

  @override
  State<FavoritesPage> createState() => _FavoritesPageState();
}

class _FavoritesPageState extends State<FavoritesPage> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      FavoritesService().refreshLiveStatus();
    });
  }

  void _openLiveRoom(
      BuildContext context, ModelData model, List<ModelData> playlist, int index) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => LiveRoomPage(
          model: model,
          playlist: playlist,
          startIndex: index,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Consumer<FavoritesService>(
        builder: (context, fav, _) {
          return Column(
            children: [
              _buildHeader(fav),
              Expanded(
                child: fav.favorites.isEmpty
                    ? _buildEmpty()
                    : RefreshIndicator(
                        onRefresh: () => fav.refreshLiveStatus(force: true),
                        color: const Color(0xFFFF4081),
                        backgroundColor: const Color(0xFF1E1E2E),
                        child: _buildGroupedList(fav),
                      ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildHeader(FavoritesService fav) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Row(
        children: [
          const Icon(Icons.favorite, color: Color(0xFFFF4081)),
          const SizedBox(width: 8),
          const Text(
            '我的收藏',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const Spacer(),
          if (fav.isRefreshing)
            const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: Color(0xFFFF4081),
              ),
            ),
          const SizedBox(width: 8),
          Text(
            '${fav.liveCount}在播 / ${fav.count}总',
            style: TextStyle(
              fontSize: 13,
              color: Colors.white.withValues(alpha: 0.6),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmpty() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.favorite_border,
              size: 64, color: Colors.white.withValues(alpha: 0.3)),
          const SizedBox(height: 16),
          Text(
            '还没有收藏任何主播',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.5),
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '在直播间双击视频即可快速收藏',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.4),
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGroupedList(FavoritesService fav) {
    final live = fav.liveFavorites;
    final offline = fav.offlineFavorites;

    return CustomScrollView(
      slivers: [
        // 正在直播分组
        if (live.isNotEmpty) ...[
          SliverToBoxAdapter(
            child: _sectionHeader(
              '正在直播',
              live.length,
              Colors.redAccent,
              Icons.live_tv,
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            sliver: SliverGrid(
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                childAspectRatio: 0.75,
                crossAxisSpacing: 8,
                mainAxisSpacing: 8,
              ),
              delegate: SliverChildBuilderDelegate(
                (context, index) {
                  final model = live[index];
                  return Dismissible(
                    key: Key('fav_live_${model.id}'),
                    direction: DismissDirection.endToStart,
                    background: _dismissBg(),
                    onDismissed: (_) => fav.removeFavorite(model.id),
                    child: ModelCard(
                      model: model,
                      onTap: () => _openLiveRoom(context, model, live, index),
                    ),
                  );
                },
                childCount: live.length,
              ),
            ),
          ),
        ],
        // 未开播分组
        if (offline.isNotEmpty) ...[
          SliverToBoxAdapter(
            child: _sectionHeader(
              '未开播',
              offline.length,
              Colors.grey,
              Icons.tv_off,
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            sliver: SliverGrid(
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                childAspectRatio: 0.75,
                crossAxisSpacing: 8,
                mainAxisSpacing: 8,
              ),
              delegate: SliverChildBuilderDelegate(
                (context, index) {
                  final model = offline[index];
                  return Dismissible(
                    key: Key('fav_off_${model.id}'),
                    direction: DismissDirection.endToStart,
                    background: _dismissBg(),
                    onDismissed: (_) => fav.removeFavorite(model.id),
                    child: ModelCard(
                      model: model,
                      onTap: () =>
                          _openLiveRoom(context, model, fav.favorites, 
                              fav.favorites.indexWhere((m) => m.id == model.id)),
                    ),
                  );
                },
                childCount: offline.length,
              ),
            ),
          ),
        ],
        const SliverPadding(padding: EdgeInsets.only(bottom: 16)),
      ],
    );
  }

  Widget _sectionHeader(
      String title, int count, Color color, IconData icon) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Row(
        children: [
          Icon(icon, color: color, size: 18),
          const SizedBox(width: 6),
          Text(
            title,
            style: TextStyle(
              color: color,
              fontSize: 15,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              '$count',
              style: TextStyle(color: color, fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }

  Widget _dismissBg() {
    return Container(
      alignment: Alignment.centerRight,
      padding: const EdgeInsets.only(right: 20),
      decoration: BoxDecoration(
        color: Colors.redAccent,
        borderRadius: BorderRadius.circular(12),
      ),
      child: const Icon(Icons.delete, color: Colors.white),
    );
  }
}

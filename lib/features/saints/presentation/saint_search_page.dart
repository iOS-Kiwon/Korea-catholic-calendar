import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../application/saint_providers.dart';
import '../model/saint.dart';

class SaintSearchPage extends ConsumerStatefulWidget {
  const SaintSearchPage({super.key});

  @override
  ConsumerState<SaintSearchPage> createState() => _SaintSearchPageState();
}

class _SaintSearchPageState extends ConsumerState<SaintSearchPage> {
  static const _pageSize = 30;

  final _controller = TextEditingController();
  final _scrollController = ScrollController();
  String _query = '';
  List<Saint> _items = const [];
  Timer? _debounce;
  bool _loading = false;
  bool _loadingMore = false;
  bool _hasMore = false;
  int _nextOffset = 0;
  int _requestId = 0;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_maybeLoadMore);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _onChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 250), () {
      if (mounted) _startSearch(value.trim());
    });
  }

  Future<void> _startSearch(String query) async {
    _requestId += 1;
    final requestId = _requestId;
    setState(() {
      _query = query;
      _items = const [];
      _nextOffset = 0;
      _hasMore = false;
      _loading = query.isNotEmpty;
      _loadingMore = false;
    });
    if (query.isEmpty) return;

    final result = await ref
        .read(saintSourceProvider)
        .searchPage(query, limit: _pageSize);
    if (!mounted || requestId != _requestId) return;
    setState(() {
      _items = result.items;
      _nextOffset = result.nextOffset;
      _hasMore = result.hasMore;
      _loading = false;
    });
  }

  Future<void> _loadMore() async {
    if (_query.isEmpty || !_hasMore || _loading || _loadingMore) return;
    final requestId = _requestId;
    setState(() {
      _loadingMore = true;
    });
    final result = await ref
        .read(saintSourceProvider)
        .searchPage(_query, limit: _pageSize, offset: _nextOffset);
    if (!mounted || requestId != _requestId) return;
    setState(() {
      _items = [..._items, ...result.items];
      _nextOffset = result.nextOffset;
      _hasMore = result.hasMore;
      _loadingMore = false;
    });
  }

  void _maybeLoadMore() {
    if (!_scrollController.hasClients) return;
    final position = _scrollController.position;
    if (position.extentAfter < 360) {
      _loadMore();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('성인 검색')),
      body: SafeArea(
        top: false,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
              child: TextField(
                controller: _controller,
                autofocus: true,
                textInputAction: TextInputAction.search,
                onChanged: _onChanged,
                onSubmitted: (value) {
                  _debounce?.cancel();
                  _startSearch(value.trim());
                },
                decoration: const InputDecoration(
                  labelText: '이름 검색',
                  hintText: '예: 체칠리아, 세실리아, Cecilia',
                  prefixIcon: Icon(Icons.search),
                ),
              ),
            ),
            Expanded(
              child: _query.isEmpty
                  ? const _EmptySearch()
                  : _loading
                  ? const Center(child: CircularProgressIndicator())
                  : _items.isEmpty
                  ? const _Message('검색 결과가 없습니다.')
                  : ListView.separated(
                      controller: _scrollController,
                      padding: const EdgeInsets.fromLTRB(8, 4, 8, 16),
                      itemCount:
                          _items.length + (_hasMore || _loadingMore ? 1 : 0),
                      separatorBuilder: (_, index) => index >= _items.length - 1
                          ? const SizedBox.shrink()
                          : const Divider(height: 1),
                      itemBuilder: (context, index) {
                        if (index >= _items.length) {
                          return const Padding(
                            padding: EdgeInsets.symmetric(vertical: 18),
                            child: Center(child: CircularProgressIndicator()),
                          );
                        }
                        final saint = _items[index];
                        return ListTile(
                          title: Text(saint.nameKo),
                          subtitle: Text(saint.subtitle),
                          trailing: const Icon(Icons.chevron_right),
                          onTap: () => Navigator.of(context).pop(saint),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptySearch extends StatelessWidget {
  const _EmptySearch();

  @override
  Widget build(BuildContext context) {
    return const _Message('성인 이름이나 세례명을 입력하세요.');
  }
}

class _Message extends StatelessWidget {
  const _Message(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Text(
          text,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
      ),
    );
  }
}

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../application/saint_providers.dart';

class SaintSearchPage extends ConsumerStatefulWidget {
  const SaintSearchPage({super.key});

  @override
  ConsumerState<SaintSearchPage> createState() => _SaintSearchPageState();
}

class _SaintSearchPageState extends ConsumerState<SaintSearchPage> {
  final _controller = TextEditingController();
  String _query = '';
  Timer? _debounce;

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _onChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 250), () {
      if (mounted) setState(() => _query = value.trim());
    });
  }

  @override
  Widget build(BuildContext context) {
    final results = ref.watch(saintSearchProvider(_query));
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
                onSubmitted: (value) => setState(() => _query = value.trim()),
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
                  : results.when(
                      loading: () =>
                          const Center(child: CircularProgressIndicator()),
                      error: (_, _) => const _Message('검색하지 못했습니다.'),
                      data: (items) => items.isEmpty
                          ? const _Message('검색 결과가 없습니다.')
                          : ListView.separated(
                              padding: const EdgeInsets.fromLTRB(8, 4, 8, 16),
                              itemCount: items.length,
                              separatorBuilder: (_, _) =>
                                  const Divider(height: 1),
                              itemBuilder: (context, index) {
                                final saint = items[index];
                                return ListTile(
                                  title: Text(saint.nameKo),
                                  subtitle: Text(saint.subtitle),
                                  trailing: const Icon(Icons.chevron_right),
                                  onTap: () => Navigator.of(context).pop(saint),
                                );
                              },
                            ),
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

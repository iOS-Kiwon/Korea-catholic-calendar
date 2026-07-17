import 'dart:async';

import 'package:flutter/material.dart';

import '../support_models.dart';
import '../support_purchase.dart';

Future<void> showSupportSheet(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (_) => const SupportSheet(),
  );
}

class SupportSheet extends StatefulWidget {
  const SupportSheet({super.key});

  @override
  State<SupportSheet> createState() => _SupportSheetState();
}

class _SupportSheetState extends State<SupportSheet> {
  late final Future<List<SupportPurchaseOption>> _products;
  StreamSubscription<SupportPurchaseEvent>? _subscription;
  String? _buyingId;

  @override
  void initState() {
    super.initState();
    final store = SupportPurchaseStore.instance;
    _products = store.loadProducts();
    _subscription = store.events.listen(_onPurchaseEvent);
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }

  Future<void> _buy(SupportPurchaseOption option) async {
    setState(() => _buyingId = option.item.id);
    try {
      await SupportPurchaseStore.instance.buy(option.item.id);
    } catch (e) {
      if (!mounted) return;
      setState(() => _buyingId = null);
      _showMessage('결제를 시작하지 못했습니다. $e');
    }
  }

  void _onPurchaseEvent(SupportPurchaseEvent event) {
    if (!mounted) return;
    setState(() => _buyingId = null);
    _showMessage(event.message);
    if (event.type == SupportPurchaseEventType.completed) {
      Navigator.of(context).maybePop();
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          20,
          0,
          20,
          20 + MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: FutureBuilder<List<SupportPurchaseOption>>(
            future: _products,
            builder: (context, snapshot) {
              final products = snapshot.data;
              return Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    '나눔으로 응원하기',
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    supportDisclosure,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 18),
                  if (snapshot.connectionState != ConnectionState.done)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 28),
                      child: Center(child: CircularProgressIndicator()),
                    )
                  else if (snapshot.hasError)
                    _ErrorBox(message: '상품 정보를 불러오지 못했습니다.\n${snapshot.error}')
                  else
                    for (final product in products ?? <SupportPurchaseOption>[])
                      Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: _SupportProductTile(
                          option: product,
                          busy: _buyingId == product.item.id,
                          onPressed: product.enabled && _buyingId == null
                              ? () => _buy(product)
                              : null,
                        ),
                      ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

class _SupportProductTile extends StatelessWidget {
  const _SupportProductTile({
    required this.option,
    required this.busy,
    required this.onPressed,
  });

  final SupportPurchaseOption option;
  final bool busy;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border.all(color: theme.colorScheme.outlineVariant),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    option.item.title,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    option.disabledReason ?? option.item.description,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            FilledButton(
              onPressed: onPressed,
              child: busy
                  ? const SizedBox.square(
                      dimension: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Text(option.price),
            ),
          ],
        ),
      ),
    );
  }
}

class _ErrorBox extends StatelessWidget {
  const _ErrorBox({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: theme.colorScheme.errorContainer,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Text(
          message,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onErrorContainer,
          ),
        ),
      ),
    );
  }
}

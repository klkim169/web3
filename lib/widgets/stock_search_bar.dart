import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/stock_provider.dart';

class StockSearchBar extends StatefulWidget {
  const StockSearchBar({super.key});

  @override
  State<StockSearchBar> createState() => _StockSearchBarState();
}

class _StockSearchBarState extends State<StockSearchBar> {
  final _controller = TextEditingController();
  final _focusNode = FocusNode();
  final _layerLink = LayerLink();
  List<Map<String, String>> _results = [];
  bool _isSearching = false;
  Timer? _debounce;
  OverlayEntry? _overlay;

  @override
  void dispose() {
    _removeOverlay();
    _controller.dispose();
    _focusNode.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  void _onChanged(String query) {
    _debounce?.cancel();
    if (query.trim().isEmpty) {
      setState(() => _results = []);
      _refreshOverlay();
      return;
    }
    _debounce = Timer(const Duration(milliseconds: 400), () => _search(query));
  }

  Future<void> _search(String query) async {
    setState(() => _isSearching = true);
    final results = await context.read<StockProvider>().searchStocks(query);
    if (mounted) {
      setState(() {
        _results = results;
        _isSearching = false;
      });
      _refreshOverlay();
    }
  }

  Future<void> _addStock(Map<String, String> stock) async {
    _debounce?.cancel();
    _controller.clear();
    setState(() {
      _results = [];
      _isSearching = false;
    });
    _removeOverlay();
    _focusNode.unfocus();
    await context.read<StockProvider>().addStock(
          stock['ticker']!,
          stock['name']!,
        );
  }

  void _onSubmitted(String _) {
    if (_results.isNotEmpty) _addStock(_results.first);
  }

  void _clear() {
    _debounce?.cancel();
    _controller.clear();
    setState(() {
      _results = [];
      _isSearching = false;
    });
    _removeOverlay();
  }

  // ── Overlay 드롭다운 ──────────────────────────────
  void _refreshOverlay() {
    if (_results.isEmpty) {
      _removeOverlay();
      return;
    }
    if (_overlay == null) {
      _overlay = _buildOverlay();
      Overlay.of(context).insert(_overlay!);
    } else {
      _overlay!.markNeedsBuild();
    }
  }

  void _removeOverlay() {
    _overlay?.remove();
    _overlay = null;
  }

  OverlayEntry _buildOverlay() {
    return OverlayEntry(
      builder: (_) {
        return Positioned(
          width: 420,
          child: CompositedTransformFollower(
            link: _layerLink,
            showWhenUnlinked: false,
            // 검색창 좌하단에서 오른쪽 정렬되도록 followerAnchor 사용
            targetAnchor: Alignment.bottomRight,
            followerAnchor: Alignment.topRight,
            offset: const Offset(0, 6),
            child: Material(
              color: Colors.transparent,
              child: Container(
                constraints: const BoxConstraints(maxHeight: 320),
                decoration: BoxDecoration(
                  color: const Color(0xFF21262D),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.white12),
                  boxShadow: const [
                    BoxShadow(
                        color: Colors.black54,
                        blurRadius: 12,
                        offset: Offset(0, 6)),
                  ],
                ),
                child: SingleChildScrollView(
                  physics: const ClampingScrollPhysics(),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      for (int i = 0; i < _results.length; i++) ...[
                        _ResultItem(
                          ticker: _results[i]['ticker']!,
                          name: _results[i]['name']!,
                          showEnterHint: i == 0,
                          onTap: () => _addStock(_results[i]),
                        ),
                        if (i < _results.length - 1)
                          const Divider(
                              height: 1, thickness: 1, color: Colors.white10),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return CompositedTransformTarget(
      link: _layerLink,
      child: SizedBox(
        height: 40,
        child: TextField(
          controller: _controller,
          focusNode: _focusNode,
          style: const TextStyle(color: Colors.white, fontSize: 14),
          decoration: InputDecoration(
            hintText: '종목 검색 — 클릭 또는 Enter로 추가',
            hintStyle: const TextStyle(color: Colors.white38, fontSize: 13),
            prefixIcon:
                const Icon(Icons.search, color: Colors.white38, size: 18),
            prefixIconConstraints:
                const BoxConstraints(minWidth: 36, minHeight: 36),
            suffixIcon: _isSearching
                ? const Padding(
                    padding: EdgeInsets.all(11),
                    child: SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white54),
                    ),
                  )
                : (_controller.text.isNotEmpty
                    ? IconButton(
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(
                            minWidth: 36, minHeight: 36),
                        icon: const Icon(Icons.close,
                            color: Colors.white38, size: 16),
                        onPressed: _clear,
                      )
                    : null),
            filled: true,
            fillColor: const Color(0xFF21262D),
            isDense: true,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide.none,
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide:
                  const BorderSide(color: Color(0xFF388BFD), width: 1),
            ),
            contentPadding: const EdgeInsets.symmetric(vertical: 8),
          ),
          onChanged: _onChanged,
          onSubmitted: _onSubmitted,
        ),
      ),
    );
  }
}

class _ResultItem extends StatefulWidget {
  final String ticker;
  final String name;
  final bool showEnterHint;
  final VoidCallback onTap;

  const _ResultItem({
    required this.ticker,
    required this.name,
    required this.showEnterHint,
    required this.onTap,
  });

  @override
  State<_ResultItem> createState() => _ResultItemState();
}

class _ResultItemState extends State<_ResultItem> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 80),
          color: _hovered
              ? const Color(0xFF388BFD).withAlpha(20)
              : Colors.transparent,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(
            children: [
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color(0xFF388BFD).withAlpha(30),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  widget.ticker,
                  style: const TextStyle(
                    color: Color(0xFF388BFD),
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  widget.name,
                  style:
                      const TextStyle(color: Colors.white70, fontSize: 13),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (widget.showEnterHint)
                const Text('Enter',
                    style: TextStyle(color: Colors.white24, fontSize: 11)),
            ],
          ),
        ),
      ),
    );
  }
}

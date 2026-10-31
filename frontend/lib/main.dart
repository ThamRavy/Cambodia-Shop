import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';

import 'api/shop_api.dart';
import 'models/product.dart';
import 'store_state.dart';

void main() {
  runApp(StorefrontApp(store: StoreState(ShopApi())));
}

const _ink = Color(0xFF1E2B25);
const _green = Color(0xFF296B50);
const _paper = Color(0xFFF7F7F1);
const _muted = Color(0xFF788078);

class StorefrontApp extends StatelessWidget {
  const StorefrontApp({required this.store, super.key});

  final StoreState store;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Cambodia Shop',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        scaffoldBackgroundColor: _paper,
        colorScheme: ColorScheme.fromSeed(
          seedColor: _green,
          primary: _green,
          surface: _paper,
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: _paper,
          foregroundColor: _ink,
          surfaceTintColor: Colors.transparent,
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: Colors.white,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide.none,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: Color(0xFFE7E9E2)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: _green, width: 1.5),
          ),
        ),
      ),
      home: StoreHome(store: store),
    );
  }
}

class StoreHome extends StatefulWidget {
  const StoreHome({required this.store, super.key});

  final StoreState store;

  @override
  State<StoreHome> createState() => _StoreHomeState();
}

class _StoreHomeState extends State<StoreHome> {
  int _tab = 0;

  @override
  void initState() {
    super.initState();
    widget.store.loadProducts();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: widget.store,
      builder: (context, _) {
        final pages = [
          ShopScreen(store: widget.store),
          CartScreen(store: widget.store),
          OrdersScreen(store: widget.store),
          AccountScreen(store: widget.store),
        ];
        return Scaffold(
          appBar: AppBar(
            title: const _BrandMark(),
            actions: [
              IconButton(
                tooltip: 'Shopping bag',
                onPressed: () => setState(() => _tab = 1),
                icon: Badge(
                  isLabelVisible: widget.store.cartCount > 0,
                  label: Text('${widget.store.cartCount}'),
                  child: const Icon(Icons.shopping_bag_outlined),
                ),
              ),
              const SizedBox(width: 8),
            ],
          ),
          body: IndexedStack(index: _tab, children: pages),
          bottomNavigationBar: NavigationBar(
            selectedIndex: _tab,
            onDestinationSelected: (index) => setState(() => _tab = index),
            destinations: const [
              NavigationDestination(
                icon: Icon(Icons.storefront_outlined),
                selectedIcon: Icon(Icons.storefront),
                label: 'Shop',
              ),
              NavigationDestination(
                icon: Icon(Icons.shopping_bag_outlined),
                selectedIcon: Icon(Icons.shopping_bag),
                label: 'Cart',
              ),
              NavigationDestination(
                icon: Icon(Icons.receipt_long_outlined),
                selectedIcon: Icon(Icons.receipt_long),
                label: 'Orders',
              ),
              NavigationDestination(
                icon: Icon(Icons.person_outline),
                selectedIcon: Icon(Icons.person),
                label: 'Account',
              ),
            ],
          ),
        );
      },
    );
  }
}

class _BrandMark extends StatelessWidget {
  const _BrandMark();

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            color: _green,
            borderRadius: BorderRadius.circular(11),
          ),
          child: const Icon(Icons.spa, color: Colors.white, size: 20),
        ),
        const SizedBox(width: 10),
        const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'CAMBODIA SHOP',
              style: TextStyle(
                fontSize: 14,
                letterSpacing: 1.15,
                fontWeight: FontWeight.w800,
                color: _ink,
              ),
            ),
            Text(
              'GOOD THINGS, CLOSE TO HOME',
              style: TextStyle(
                fontSize: 8,
                letterSpacing: 1.1,
                color: _muted,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class ShopScreen extends StatefulWidget {
  const ShopScreen({required this.store, super.key});

  final StoreState store;

  @override
  State<ShopScreen> createState() => _ShopScreenState();
}

class _ShopScreenState extends State<ShopScreen> {
  String? _category;
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final categories =
        widget.store.products
            .map((product) => product.category)
            .toSet()
            .toList()
          ..sort();
    final visibleProducts = widget.store.products.where((product) {
      final matchesCategory =
          _category == null || product.category == _category;
      final searchText =
          '${product.name} ${product.description} ${product.category}'
              .toLowerCase();
      return matchesCategory && searchText.contains(_query.toLowerCase());
    }).toList();

    return RefreshIndicator(
      onRefresh: widget.store.loadProducts,
      child: CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const _WelcomeBanner(),
                  const SizedBox(height: 22),
                  TextField(
                    onChanged: (value) => setState(() => _query = value.trim()),
                    decoration: const InputDecoration(
                      hintText: 'Search the shop',
                      prefixIcon: Icon(Icons.search),
                    ),
                  ),
                  const SizedBox(height: 17),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        _CategoryChip(
                          label: 'All',
                          selected: _category == null,
                          onSelected: () {
                            setState(() => _category = null);
                          },
                        ),
                        ...categories.map(
                          (category) => _CategoryChip(
                            label: category,
                            selected: _category == category,
                            onSelected: () {
                              setState(() => _category = category);
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 23),
                  Row(
                    children: [
                      const Expanded(
                        child: Text(
                          'Made for you',
                          style: TextStyle(
                            color: _ink,
                            fontSize: 21,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                      Text(
                        '${visibleProducts.length} items',
                        style: const TextStyle(color: _muted, fontSize: 13),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          if (widget.store.loadingProducts && widget.store.products.isEmpty)
            const SliverFillRemaining(
              hasScrollBody: false,
              child: Center(child: CircularProgressIndicator()),
            )
          else if (widget.store.productsError != null &&
              widget.store.products.isEmpty)
            SliverFillRemaining(
              hasScrollBody: false,
              child: _ErrorState(
                message: widget.store.productsError!,
                onRetry: widget.store.loadProducts,
              ),
            )
          else if (visibleProducts.isEmpty)
            const SliverFillRemaining(
              hasScrollBody: false,
              child: _EmptyState(
                icon: Icons.search_off,
                title: 'Nothing here yet',
                message: 'Try a different search or browse all products.',
              ),
            )
          else
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 28),
              sliver: SliverLayoutBuilder(
                builder: (context, constraints) {
                  final width = constraints.crossAxisExtent;
                  final columns = width >= 1000
                      ? 4
                      : width >= 650
                      ? 3
                      : 2;
                  return SliverGrid(
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: columns,
                      crossAxisSpacing: 14,
                      mainAxisSpacing: 14,
                      childAspectRatio: width < 380 ? 0.63 : 0.7,
                    ),
                    delegate: SliverChildBuilderDelegate(
                      (context, index) => ProductCard(
                        product: visibleProducts[index],
                        onTap: () => _showProduct(
                          context,
                          widget.store,
                          visibleProducts[index],
                        ),
                      ),
                      childCount: visibleProducts.length,
                    ),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }

  void _showProduct(BuildContext context, StoreState store, Product product) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) => Padding(
        padding: EdgeInsets.fromLTRB(
          22,
          4,
          22,
          MediaQuery.viewInsetsOf(context).bottom + 28,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ProductImage(product: product, height: 220),
            const SizedBox(height: 18),
            Text(
              product.name,
              style: const TextStyle(
                color: _ink,
                fontSize: 24,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 6),
            Text(product.description, style: const TextStyle(color: _muted)),
            const SizedBox(height: 18),
            Row(
              children: [
                Expanded(
                  child: Text(
                    money(product.priceCents),
                    style: const TextStyle(
                      color: _green,
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                FilledButton.icon(
                  onPressed: product.stock == 0
                      ? null
                      : () {
                          store.addToCart(product);
                          Navigator.pop(context);
                        },
                  icon: const Icon(Icons.add_shopping_cart),
                  label: Text(product.stock == 0 ? 'Sold out' : 'Add to bag'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _WelcomeBanner extends StatelessWidget {
  const _WelcomeBanner();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: const Color(0xFFE7EFE6),
        borderRadius: BorderRadius.circular(22),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'A little closer\n to home.',
                  style: TextStyle(
                    color: _ink,
                    fontSize: 25,
                    height: 1.08,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 9),
                const Text(
                  'Discover thoughtful finds from Cambodia.',
                  style: TextStyle(color: _muted, fontSize: 13),
                ),
                const SizedBox(height: 15),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 7,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.7),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Text(
                    'SHOP THE COLLECTION  →',
                    style: TextStyle(
                      color: _green,
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.4,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Container(
            width: 78,
            height: 78,
            decoration: BoxDecoration(
              color: const Color(0xFFD4E3D3),
              borderRadius: BorderRadius.circular(24),
            ),
            child: const Icon(Icons.local_florist, color: _green, size: 42),
          ),
        ],
      ),
    );
  }
}

class _CategoryChip extends StatelessWidget {
  const _CategoryChip({
    required this.label,
    required this.selected,
    required this.onSelected,
  });

  final String label;
  final bool selected;
  final VoidCallback onSelected;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ChoiceChip(
        label: Text(label),
        selected: selected,
        onSelected: (_) => onSelected(),
        showCheckmark: false,
        labelStyle: TextStyle(
          color: selected ? Colors.white : _ink,
          fontWeight: FontWeight.w600,
        ),
        selectedColor: _green,
        backgroundColor: Colors.white,
        side: BorderSide(color: selected ? _green : const Color(0xFFE7E9E2)),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
      ),
    );
  }
}

class ProductCard extends StatelessWidget {
  const ProductCard({required this.product, required this.onTap, super.key});

  final Product product;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(19),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: ProductImage(product: product)),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    product.category.toUpperCase(),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: _muted,
                      fontSize: 9,
                      letterSpacing: 1,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    product.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: _ink,
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 7),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          money(product.priceCents),
                          style: const TextStyle(
                            color: _green,
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                      const Icon(Icons.add_circle, color: _green, size: 22),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class ProductImage extends StatelessWidget {
  const ProductImage({required this.product, this.height, super.key});

  final Product product;
  final double? height;

  @override
  Widget build(BuildContext context) {
    final imageUrl = product.imageUrl;
    return SizedBox(
      width: double.infinity,
      height: height,
      child: imageUrl != null && imageUrl.isNotEmpty
          ? Image.network(
              imageUrl,
              fit: BoxFit.cover,
              errorBuilder: (_, _, _) => const _ImagePlaceholder(),
            )
          : const _ImagePlaceholder(),
    );
  }
}

class _ImagePlaceholder extends StatelessWidget {
  const _ImagePlaceholder();

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFFE7EFE6),
      child: const Center(
        child: Icon(Icons.inventory_2_outlined, color: _green, size: 40),
      ),
    );
  }
}

class CartScreen extends StatelessWidget {
  const CartScreen({required this.store, super.key});

  final StoreState store;

  @override
  Widget build(BuildContext context) {
    final products = store.products
        .where((product) => store.quantityFor(product) > 0)
        .toList();
    if (products.isEmpty) {
      return const _EmptyState(
        icon: Icons.shopping_bag_outlined,
        title: 'Your bag is taking a break',
        message: 'Add something you love and it will show up here.',
      );
    }
    return Column(
      children: [
        Expanded(
          child: ListView.separated(
            padding: const EdgeInsets.all(20),
            itemCount: products.length,
            separatorBuilder: (_, _) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              final product = products[index];
              return _CartItem(product: product, store: store);
            },
          ),
        ),
        SafeArea(
          top: false,
          child: Container(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 18),
            decoration: const BoxDecoration(
              color: Colors.white,
              border: Border(top: BorderSide(color: Color(0xFFE7E9E2))),
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    const Expanded(
                      child: Text('Subtotal', style: TextStyle(color: _muted)),
                    ),
                    Text(
                      money(store.cartTotalCents),
                      key: const ValueKey('cart-subtotal'),
                      style: const TextStyle(
                        color: _ink,
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: () => _openCheckout(context),
                    child: const Padding(
                      padding: EdgeInsets.symmetric(vertical: 13),
                      child: Text('Continue to checkout'),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _openCheckout(BuildContext context) async {
    if (store.token == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Sign in from Account before checkout.')),
      );
      return;
    }
    final order = await showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => CheckoutSheet(store: store),
    );
    if (order != null && context.mounted) {
      await _startQrPayment(context, store, order);
    }
  }
}

Future<void> _startQrPayment(
  BuildContext context,
  StoreState store,
  Map<String, dynamic> order,
) async {
  try {
    final checkout = await store.createQrCheckout('${order['id'] ?? ''}');
    if (!context.mounted) return;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) =>
          QrPaymentSheet(store: store, order: order, checkout: checkout),
    );
  } catch (error) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Order ${order['orderNumber'] ?? ''} was created, but ABA QR checkout could not start: $error',
        ),
        duration: const Duration(seconds: 8),
      ),
    );
  }
}

class _CartItem extends StatelessWidget {
  const _CartItem({required this.product, required this.store});

  final Product product;
  final StoreState store;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(13),
            child: SizedBox(
              width: 76,
              height: 76,
              child: ProductImage(product: product),
            ),
          ),
          const SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  product.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: _ink,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  money(product.priceCents),
                  style: const TextStyle(
                    color: _green,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    _QuantityButton(
                      icon: Icons.remove,
                      onTap: () => store.removeFromCart(product),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      child: Text(
                        '${store.quantityFor(product)}',
                        key: ValueKey('cart-quantity-${product.id}'),
                      ),
                    ),
                    _QuantityButton(
                      icon: Icons.add,
                      onTap: () => store.addToCart(product),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Text(
            money(product.priceCents * store.quantityFor(product)),
            key: ValueKey('cart-line-total-${product.id}'),
            style: const TextStyle(
              color: _ink,
              fontSize: 13,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _QuantityButton extends StatelessWidget {
  const _QuantityButton({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        width: 27,
        height: 27,
        decoration: BoxDecoration(
          color: _paper,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, size: 15, color: _ink),
      ),
    );
  }
}

class CheckoutSheet extends StatefulWidget {
  const CheckoutSheet({required this.store, super.key});

  final StoreState store;

  @override
  State<CheckoutSheet> createState() => _CheckoutSheetState();
}

class _CheckoutSheetState extends State<CheckoutSheet> {
  final _formKey = GlobalKey<FormState>();
  final _recipient = TextEditingController();
  final _phone = TextEditingController();
  final _address = TextEditingController();
  final _city = TextEditingController(text: 'Phnom Penh');
  String? _error;
  bool _sending = false;

  @override
  void dispose() {
    _recipient.dispose();
    _phone.dispose();
    _address.dispose();
    _city.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        22,
        4,
        22,
        MediaQuery.viewInsetsOf(context).bottom + 24,
      ),
      child: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Delivery details',
                style: TextStyle(
                  color: _ink,
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                'Your order total is calculated securely by the shop.',
                style: TextStyle(color: _muted),
              ),
              const SizedBox(height: 18),
              _CheckoutField(
                controller: _recipient,
                label: 'Recipient name (optional)',
              ),
              const SizedBox(height: 11),
              _CheckoutField(
                controller: _phone,
                label: 'Phone (optional)',
                keyboardType: TextInputType.phone,
              ),
              const SizedBox(height: 11),
              _CheckoutField(
                controller: _address,
                label: 'Street address',
                validator: _required,
              ),
              const SizedBox(height: 11),
              _CheckoutField(
                controller: _city,
                label: 'City',
                validator: _required,
              ),
              if (_error != null) ...[
                const SizedBox(height: 12),
                Text(_error!, style: const TextStyle(color: Colors.red)),
              ],
              const SizedBox(height: 17),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: _sending ? null : _submit,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 13),
                    child: _sending
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Text('Place order'),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              const Center(
                child: Text(
                  'Payment is not collected in this step.',
                  style: TextStyle(color: _muted, fontSize: 12),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String? _required(String? value) =>
      value == null || value.trim().isEmpty ? 'This field is required.' : null;

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _sending = true;
      _error = null;
    });
    try {
      final order = await widget.store.placeOrder(
        recipient: _recipient.text.trim(),
        phone: _phone.text.trim(),
        addressLine: _address.text.trim(),
        city: _city.text.trim(),
      );
      if (mounted) Navigator.pop(context, order);
    } catch (error) {
      if (mounted) setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }
}

class _CheckoutField extends StatelessWidget {
  const _CheckoutField({
    required this.controller,
    required this.label,
    this.validator,
    this.keyboardType,
  });

  final TextEditingController controller;
  final String label;
  final String? Function(String?)? validator;
  final TextInputType? keyboardType;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      decoration: InputDecoration(labelText: label),
      validator: validator,
      keyboardType: keyboardType,
      textCapitalization: TextCapitalization.sentences,
    );
  }
}

class OrdersScreen extends StatefulWidget {
  const OrdersScreen({required this.store, super.key});

  final StoreState store;

  @override
  State<OrdersScreen> createState() => _OrdersScreenState();
}

class _OrdersScreenState extends State<OrdersScreen> {
  List<Map<String, dynamic>> _orders = [];
  bool _loading = false;
  String? _error;
  String? _observedToken;
  int _observedOrderRevision = 0;

  @override
  void initState() {
    super.initState();
    _observedToken = widget.store.token;
    _observedOrderRevision = widget.store.orderRevision;
    widget.store.addListener(_onStoreChanged);
    _loadOrders();
  }

  @override
  void didUpdateWidget(covariant OrdersScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.store != widget.store) {
      oldWidget.store.removeListener(_onStoreChanged);
      _observedToken = widget.store.token;
      _observedOrderRevision = widget.store.orderRevision;
      widget.store.addListener(_onStoreChanged);
      _loadOrders();
    }
  }

  @override
  void dispose() {
    widget.store.removeListener(_onStoreChanged);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.store.token == null) {
      return const _EmptyState(
        icon: Icons.receipt_long_outlined,
        title: 'Your orders live here',
        message: 'Sign in to see orders you have placed.',
      );
    }
    return RefreshIndicator(
      onRefresh: _loadOrders,
      child: _loading && _orders.isEmpty
          ? ListView(
              physics: AlwaysScrollableScrollPhysics(),
              children: [
                SizedBox(height: 180),
                Center(child: CircularProgressIndicator()),
              ],
            )
          : _error != null && _orders.isEmpty
          ? ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              children: [
                const SizedBox(height: 120),
                _ErrorState(message: _error!, onRetry: _loadOrders),
              ],
            )
          : _orders.isEmpty
          ? ListView(
              physics: AlwaysScrollableScrollPhysics(),
              children: [
                SizedBox(height: 120),
                _EmptyState(
                  icon: Icons.receipt_long_outlined,
                  title: 'No orders yet',
                  message: 'Your first order will appear right here.',
                ),
              ],
            )
          : ListView.separated(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(20),
              itemCount: _orders.length,
              separatorBuilder: (_, _) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                final order = _orders[index];
                return _OrderCard(
                  order: order,
                  onPay: () => _startQrPayment(context, widget.store, order),
                );
              },
            ),
    );
  }

  Future<void> _loadOrders() async {
    final token = widget.store.token;
    if (token == null) {
      if (mounted) setState(() => _orders = []);
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final orders = await widget.store.api.getOrders(token);
      if (mounted) setState(() => _orders = orders);
    } catch (error) {
      if (mounted) setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _onStoreChanged() {
    if (_observedToken == widget.store.token &&
        _observedOrderRevision == widget.store.orderRevision) {
      return;
    }
    _observedToken = widget.store.token;
    _observedOrderRevision = widget.store.orderRevision;
    _loadOrders();
  }
}

class _OrderCard extends StatelessWidget {
  const _OrderCard({required this.order, required this.onPay});

  final Map<String, dynamic> order;
  final VoidCallback onPay;

  @override
  Widget build(BuildContext context) {
    final items = (order['items'] as List<dynamic>? ?? []).length;
    final total = (order['totalCents'] as num?)?.toInt() ?? 0;
    final unpaid = order['paymentStatus'] == 'unpaid';
    return Container(
      padding: const EdgeInsets.all(17),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        children: [
          Container(
            width: 45,
            height: 45,
            decoration: BoxDecoration(
              color: const Color(0xFFE7EFE6),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(Icons.inventory_2_outlined, color: _green),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${order['orderNumber'] ?? 'Order'}',
                  style: const TextStyle(
                    color: _ink,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '$items ${items == 1 ? 'item' : 'items'} · ${order['status'] ?? 'processing'}',
                  style: const TextStyle(color: _muted, fontSize: 12),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                money(total),
                style: const TextStyle(
                  color: _green,
                  fontWeight: FontWeight.w800,
                ),
              ),
              if (unpaid) ...[
                const SizedBox(height: 5),
                TextButton(
                  onPressed: onPay,
                  style: TextButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                    padding: EdgeInsets.zero,
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  child: const Text('Pay with ABA QR'),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

class QrPaymentSheet extends StatefulWidget {
  const QrPaymentSheet({
    required this.store,
    required this.order,
    required this.checkout,
    super.key,
  });

  final StoreState store;
  final Map<String, dynamic> order;
  final Map<String, dynamic> checkout;

  @override
  State<QrPaymentSheet> createState() => _QrPaymentSheetState();
}

class _QrPaymentSheetState extends State<QrPaymentSheet> {
  bool _checking = false;
  String _status = 'pending';
  String? _error;
  DateTime? _lastCheckedAt;

  String get _transactionId => '${widget.checkout['tranId'] ?? ''}';

  String? get _qrString {
    for (final key in ['qr_string', 'qrString']) {
      final value = widget.checkout[key];
      if (value is String && value.isNotEmpty) return value;
    }
    return null;
  }

  String? get _qrImageUrl {
    for (final key in ['checkout_qr_url', 'qr_image', 'qrImage']) {
      final value = widget.checkout[key];
      if (value is String && value.startsWith('http')) return value;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final paid = _status == 'approved';
    final fallbackQr = _qrImageUrl;
    return SafeArea(
      top: false,
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          22,
          4,
          22,
          MediaQuery.viewInsetsOf(context).bottom + 24,
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                paid ? 'Payment confirmed' : 'Pay with ABA KHQR',
                style: const TextStyle(
                  color: _ink,
                  fontSize: 23,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 5),
              Text(
                'Order ${widget.order['orderNumber'] ?? ''} · ${money((widget.order['totalCents'] as num?)?.toInt() ?? 0)} USD',
                textAlign: TextAlign.center,
                style: const TextStyle(color: _muted),
              ),
              const SizedBox(height: 17),
              if (paid)
                Container(
                  width: 220,
                  height: 220,
                  decoration: BoxDecoration(
                    color: const Color(0xFFE7EFE6),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Icon(
                    Icons.check_circle_outline,
                    color: _green,
                    size: 100,
                  ),
                )
              else if (_qrString != null)
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: QrImageView(
                    data: _qrString!,
                    size: 220,
                    version: QrVersions.auto,
                    backgroundColor: Colors.white,
                  ),
                )
              else if (fallbackQr != null)
                ClipRRect(
                  borderRadius: BorderRadius.circular(18),
                  child: Image.network(
                    fallbackQr,
                    width: 244,
                    height: 244,
                    fit: BoxFit.contain,
                    errorBuilder: (_, _, _) => _qrUnavailable(),
                  ),
                )
              else
                _qrUnavailable(),
              const SizedBox(height: 16),
              Text(
                paid ? 'ABA PayWay confirmed this payment.' : 'Open ABA Mobile, scan the QR code, and confirm the payment.',
                textAlign: TextAlign.center,
                style: const TextStyle(color: _muted),
              ),
              if (_transactionId.isNotEmpty) ...[
                const SizedBox(height: 9),
                SelectableText(
                  'Transaction: $_transactionId',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: _muted, fontSize: 12),
                ),
              ],
              if (_error != null) ...[
                const SizedBox(height: 12),
                Text(
                  _error!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.red),
                ),
              ],
              const SizedBox(height: 16),
              if (!paid)
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: _checking ? null : _verifyPayment,
                    icon: _checking
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.verified_outlined),
                    label: Text(
                      _checking
                          ? 'Checking payment…'
                          : 'I’ve paid — check status',
                    ),
                  ),
                )
              else
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Done'),
                  ),
                ),
              if (!paid) ...[
                const SizedBox(height: 9),
                const Text(
                  'Payment is confirmed by the server, not by the QR scan or redirect.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: _muted, fontSize: 11),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _qrUnavailable() {
    return Container(
      width: 220,
      height: 220,
      decoration: BoxDecoration(
        color: const Color(0xFFF0F1EC),
        borderRadius: BorderRadius.circular(20),
      ),
      child: const Center(
        child: Padding(
          padding: EdgeInsets.all(18),
          child: Text(
            'ABA did not return QR data. Check your PayWay sandbox credentials and response.',
            textAlign: TextAlign.center,
            style: TextStyle(color: _muted),
          ),
        ),
      ),
    );
  }

  Future<void> _verifyPayment() async {
    if (_transactionId.isEmpty) {
      setState(
        () =>
            _error = 'The checkout response did not include a transaction ID.',
      );
      return;
    }
    final now = DateTime.now();
    final previous = _lastCheckedAt;
    if (previous != null &&
        now.difference(previous) < const Duration(seconds: 8)) {
      setState(
        () => _error = 'Please wait a few seconds before checking again.',
      );
      return;
    }
    setState(() {
      _checking = true;
      _error = null;
      _lastCheckedAt = now;
    });
    try {
      final result = await widget.store.verifyPayment(_transactionId);
      if (!mounted) return;
      setState(() => _status = '${result['status'] ?? 'pending'}');
      if (_status != 'approved') {
        setState(() {
          _error = _status == 'pending'
              ? 'Payment is still pending. Complete it in ABA Mobile, then check again.'
              : 'PayWay returned: $_status';
        });
      }
    } catch (error) {
      if (mounted) setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _checking = false);
    }
  }
}

class AccountScreen extends StatefulWidget {
  const AccountScreen({required this.store, super.key});

  final StoreState store;

  @override
  State<AccountScreen> createState() => _AccountScreenState();
}

class _AccountScreenState extends State<AccountScreen> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _register = false;
  bool _sending = false;
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.store.token != null) {
      return Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 440),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(22),
              ),
              child: Column(
                children: [
                  const CircleAvatar(
                    radius: 34,
                    backgroundColor: Color(0xFFE7EFE6),
                    child: Icon(Icons.person, color: _green, size: 32),
                  ),
                  const SizedBox(height: 15),
                  Text(
                    widget.store.name ?? 'Welcome back',
                    style: const TextStyle(
                      color: _ink,
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    widget.store.email ?? '',
                    style: const TextStyle(color: _muted),
                  ),
                  const SizedBox(height: 20),
                  OutlinedButton.icon(
                    onPressed: widget.store.signOut,
                    icon: const Icon(Icons.logout),
                    label: const Text('Sign out'),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 440),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(22),
            ),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _register ? 'Join the shop' : 'Welcome back',
                    style: const TextStyle(
                      color: _ink,
                      fontSize: 24,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 7),
                  Text(
                    _register
                        ? 'Create an account to place and track orders.'
                        : 'Sign in to place orders and view your history.',
                    style: const TextStyle(color: _muted),
                  ),
                  const SizedBox(height: 21),
                  if (_register) ...[
                    TextFormField(
                      controller: _name,
                      decoration: const InputDecoration(labelText: 'Name'),
                      textCapitalization: TextCapitalization.words,
                      validator: (value) => (value?.trim().length ?? 0) < 2
                          ? 'Enter at least 2 characters.'
                          : null,
                    ),
                    const SizedBox(height: 12),
                  ],
                  TextFormField(
                    controller: _email,
                    decoration: const InputDecoration(labelText: 'Email'),
                    keyboardType: TextInputType.emailAddress,
                    validator: (value) {
                      final email = value?.trim() ?? '';
                      return email.contains('@') && email.contains('.')
                          ? null
                          : 'Enter a valid email address.';
                    },
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _password,
                    decoration: const InputDecoration(labelText: 'Password'),
                    obscureText: true,
                    validator: (value) => _register && (value?.length ?? 0) < 12
                        ? 'Use at least 12 characters.'
                        : (value?.isEmpty ?? true)
                        ? 'Enter your password.'
                        : null,
                  ),
                  if (_error != null) ...[
                    const SizedBox(height: 12),
                    Text(_error!, style: const TextStyle(color: Colors.red)),
                  ],
                  const SizedBox(height: 18),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: _sending ? null : _submit,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        child: _sending
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : Text(_register ? 'Create account' : 'Sign in'),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Center(
                    child: TextButton(
                      onPressed: () => setState(() {
                        _register = !_register;
                        _error = null;
                      }),
                      child: Text(
                        _register
                            ? 'Already have an account? Sign in'
                            : 'New here? Create an account',
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _sending = true;
      _error = null;
    });
    try {
      await widget.store.authenticate(
        register: _register,
        name: _name.text.trim(),
        email: _email.text.trim(),
        password: _password.text,
      );
    } catch (error) {
      if (mounted) setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({
    required this.icon,
    required this.title,
    required this.message,
  });

  final IconData icon;
  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: _green, size: 42),
            const SizedBox(height: 14),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: _ink,
                fontSize: 19,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 7),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(color: _muted),
            ),
          ],
        ),
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.cloud_off_outlined, color: _muted, size: 40),
            const SizedBox(height: 12),
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: const Text('Try again'),
            ),
          ],
        ),
      ),
    );
  }
}

String money(int cents) => '\$${(cents / 100).toStringAsFixed(2)}';

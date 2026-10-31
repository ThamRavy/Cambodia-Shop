class Product {
  const Product({
    required this.id,
    required this.name,
    required this.description,
    required this.category,
    required this.priceCents,
    required this.stock,
    this.imageUrl,
    this.currency = 'USD',
  });

  final String id;
  final String name;
  final String description;
  final String category;
  final int priceCents;
  final int stock;
  final String? imageUrl;
  final String currency;

  factory Product.fromJson(Map<String, dynamic> json) {
    return Product(
      id: '${json['id'] ?? ''}',
      name: '${json['name'] ?? 'Untitled product'}',
      description: '${json['description'] ?? ''}',
      category: '${json['category'] ?? 'General'}',
      priceCents: (json['priceCents'] as num?)?.toInt() ?? 0,
      stock: (json['stock'] as num?)?.toInt() ?? 0,
      imageUrl: json['imageUrl'] as String?,
      currency: '${json['currency'] ?? 'USD'}',
    );
  }
}

import 'package:test/test.dart';
void main(){
 test('integer cents avoid floating point currency arithmetic',(){final prices=[{'priceCents':1299,'quantity':2},{'priceCents':500,'quantity':1}];final total=prices.fold<int>(0,(s,p)=>s+(p['priceCents'] as int)*(p['quantity'] as int));expect(total,3098);});
 test('slug validation rejects whitespace and path separators',(){expect(RegExp(r'^[a-z0-9-]{2,100}$').hasMatch('blue-shirt'),isTrue);expect(RegExp(r'^[a-z0-9-]{2,100}$').hasMatch('../admin'),isFalse);});
}

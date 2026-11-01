import 'package:ecommerce_api/config/env.dart';
import 'package:test/test.dart';

void main() {
  test('allows production and existing preview storefront origins', () {
    expect(
      Env.isCorsOriginAllowed('https://cambodia-shop-frontend.vercel.app'),
      isTrue,
    );
    expect(
      Env.isCorsOriginAllowed(
        'https://cambodia-shop-frontend-q2o6jxrip-rupp3.vercel.app',
      ),
      isTrue,
    );
  });

  test('allows deployment previews for the Cambodia Shop Vercel project', () {
    expect(
      Env.isCorsOriginAllowed(
        'https://cambodia-shop-frontend-ppao05kv3-rupp3.vercel.app',
      ),
      isTrue,
    );
    expect(
      Env.isCorsOriginAllowed(
        'https://cambodia-shop-frontend-git-main-rupp3.vercel.app',
      ),
      isTrue,
    );
  });

  test('does not allow unrelated hosts or insecure preview origins', () {
    expect(
      Env.isCorsOriginAllowed(
        'https://cambodia-shop-frontend-git-main-otherteam.vercel.app',
      ),
      isFalse,
    );
    expect(
      Env.isCorsOriginAllowed(
        'https://cambodia-shop-frontend-ppao05kv3-rupp3.vercel.app.attacker.test',
      ),
      isFalse,
    );
    expect(
      Env.isCorsOriginAllowed(
        'http://cambodia-shop-frontend-ppao05kv3-rupp3.vercel.app',
      ),
      isFalse,
    );
  });
}

import 'package:cine_list/features/auth/presentation/cubit/auth_cubit.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Auth Form Validation', () {
    test('validateEmail rejects empty and malformed emails', () {
      expect(AuthCubit.validateEmail(''), isNotNull);
      expect(AuthCubit.validateEmail('   '), isNotNull);
      expect(AuthCubit.validateEmail('invalid-email'), isNotNull);
      expect(AuthCubit.validateEmail('user@domain'), isNotNull);
    });

    test('validateEmail accepts valid emails', () {
      expect(AuthCubit.validateEmail('yami@cinelist.app'), isNull);
      expect(AuthCubit.validateEmail('  alex.smith@uni.edu  '), isNull);
    });

    test('validatePassword enforces non-empty and min length 6', () {
      expect(AuthCubit.validatePassword(''), isNotNull);
      expect(AuthCubit.validatePassword('12345'), isNotNull);
      expect(AuthCubit.validatePassword('123456'), isNull);
      expect(AuthCubit.validatePassword('securePass!'), isNull);
    });
  });
}

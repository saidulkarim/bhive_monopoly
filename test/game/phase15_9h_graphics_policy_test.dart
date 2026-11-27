import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:monopoly/core/ui/graphics_resource_policy.dart';
import 'package:monopoly/core/utils/avatar_preview_bytes.dart';

void main() {
  test('physical decode size uses stable buckets and a bounded maximum', () {
    expect(GraphicsResourcePolicy.decodeSide(40, 2), 128);
    expect(GraphicsResourcePolicy.decodeSide(41, 2), 128);
    expect(GraphicsResourcePolicy.decodeSide(96, 3), 320);
    expect(GraphicsResourcePolicy.decodeSide(1000, 4), 512);
  });

  test('invalid dimensions use the original provider', () {
    expect(GraphicsResourcePolicy.decodeSide(0, 2), isNull);
    expect(GraphicsResourcePolicy.decodeSide(double.nan, 2), isNull);
    expect(GraphicsResourcePolicy.decodeSide(40, double.infinity), isNull);
  });

  testWidgets('bounded provider preserves aspect ratio and cache identity', (
    tester,
  ) async {
    final source = MemoryImage(Uint8List.fromList([1, 2, 3]));
    late ImageProvider<Object> first;
    late ImageProvider<Object> second;
    await tester.pumpWidget(
      MediaQuery(
        data: const MediaQueryData(devicePixelRatio: 2),
        child: Builder(
          builder: (context) {
            final a = GraphicsResourcePolicy.smallImage(context, source, 40);
            final b = GraphicsResourcePolicy.smallImage(context, source, 41);
            expect(a, isA<ResizeImage>());
            final resized = a as ResizeImage;
            expect(resized.width, 128);
            expect(resized.height, 128);
            expect(resized.policy, ResizeImagePolicy.fit);
            expect(resized.allowUpscaling, isFalse);
            first = a;
            second = b;
            return const SizedBox();
          },
        ),
      ),
    );
    expect(
      await first.obtainKey(ImageConfiguration.empty),
      await second.obtainKey(ImageConfiguration.empty),
    );
  });

  test('only zero-cycle power modes omit soft board glow', () {
    expect(GraphicsResourcePolicy.useSoftGlow(2), isTrue);
    expect(GraphicsResourcePolicy.useSoftGlow(1), isTrue);
    expect(GraphicsResourcePolicy.useSoftGlow(0), isFalse);
  });
  test('local preview reuses bytes and invalidates on a changed photo', () {
    final preview = AvatarPreviewBytes();
    final first = preview.resolve('AQID');
    expect(first, [1, 2, 3]);
    expect(identical(first, preview.resolve('AQID')), isTrue);
    expect(() => first![0] = 7, throwsUnsupportedError);
    expect(preview.resolve('BAUG'), [4, 5, 6]);
    expect(preview.resolve('invalid!'), isNull);
    expect(preview.resolve(null), isNull);
  });
}

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zhiyue/features/library/widgets/book_cover.dart';

/// 简单 fake BuildContext —— BookCover.build 实际不读取 context。
class _FakeContext implements BuildContext {
  @override
  dynamic noSuchMethod(Invocation invocation) {}
}

void main() {
  // ----- Placeholder 路径（coverFile == null）-----
  // 这两个用 testWidgets —— 因为不涉及 Image.file，没有 fakeAsync 死锁问题。
  testWidgets('renders placeholder with first character when coverFile null',
      (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(
        body: BookCover(coverFile: null, title: '测试书'),
      ),
    ));
    expect(find.text('测'), findsOneWidget);
  });

  testWidgets('renders "?" when title empty and coverFile null', (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(
        body: BookCover(coverFile: null, title: ''),
      ),
    ));
    expect(find.text('?'), findsOneWidget);
  });

  // ----- Image 路径（coverFile != null）-----
  // 这两个不用 testWidgets —— Flutter 的 FileImage._loadAsync 会调用
  // file.length() 和 ui.ImmutableBuffer.fromFilePath()，这些是真实异步 IO，
  // 在 flutter_test 的 FakeAsync zone 中永远不会完成，导致测试 "did not complete"
  // （即使包在 tester.runAsync 中也无济于事 —— 见 Flutter issue #38997）。
  //
  // 改用纯单元测试：直接调用 BookCover.build() 检查返回的 widget 树结构。
  // build() 是纯函数，不会触发 didChangeDependencies → _resolveImage。
  test('BookCover.build returns AspectRatio>Image when coverFile provided',
      () {
    final cover = BookCover(
      coverFile: File('/nonexistent.png'), // 路径不存在无所谓 —— build 不读
      title: '测试书',
    );
    final widget = cover.build(_FakeContext());

    expect(widget, isA<AspectRatio>());
    final ar = widget as AspectRatio;
    expect(ar.aspectRatio, 0.7);
    expect(ar.child, isA<Image>(),
        reason: 'coverFile!=null 时应构造 Image widget');
  });

  test('BookCover.build returns _Placeholder when coverFile is null', () {
    const cover = BookCover(coverFile: null, title: '测试书');
    final widget = cover.build(_FakeContext());

    // coverFile==null 时直接返回 _Placeholder（私有类，用 runtimeType 字符串识别）
    expect(widget.runtimeType.toString(), '_Placeholder');
  });

  test('BookCover passes errorBuilder to Image (fallback seam)', () {
    final cover = BookCover(
      coverFile: File('/nonexistent.png'),
      title: '坏封面',
    );
    final widget = cover.build(_FakeContext()) as AspectRatio;
    final image = widget.child as Image;

    // 验证 errorBuilder 已设置 —— 这样坏文件解码失败时会 fallback 到 _Placeholder
    expect(image.errorBuilder, isNotNull,
        reason: '必须传 errorBuilder，否则坏封面会让整个 widget 崩');
  });

  test('BookCover respects custom aspectRatio', () {
    final cover = BookCover(
      coverFile: File('/x.png'),
      title: 'X',
      aspectRatio: 1.0,
    );
    final widget = cover.build(_FakeContext()) as AspectRatio;
    expect(widget.aspectRatio, 1.0);
  });
}

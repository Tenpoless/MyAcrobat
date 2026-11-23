import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:myacrobat_app/src/api/myacrobat_api_client.dart';
import 'package:myacrobat_app/src/models/sign_document_result.dart';
import 'package:myacrobat_app/src/models/signature_placement.dart';
import 'package:myacrobat_app/src/models/vault_pdf_file.dart';

class _RecordingHttpClientAdapter implements HttpClientAdapter {
  _RecordingHttpClientAdapter(this._handler);

  final Future<ResponseBody> Function(
    RequestOptions options,
    Uint8List? requestBytes,
  ) _handler;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    Uint8List? bytes;
    if (requestStream != null) {
      final builder = BytesBuilder(copy: false);
      await for (final chunk in requestStream) {
        builder.add(chunk);
      }
      bytes = builder.takeBytes();
    }
    return _handler(options, bytes);
  }

  @override
  void close({bool force = false}) {}
}

void main() {
  group('Domain Models (VaultPdfFile & SignaturePlacement)', () {
    test('VaultPdfFile.fromJson parses contract fields and formats size', () {
      final json = <String, dynamic>{
        'fileId': 'mega-node-01',
        'name': 'Kontrak_Kerja.pdf',
        'size': 245760,
        'updatedAt': '2026-11-20T03:00:00.000Z',
        'isSigned': false,
      };

      final file = VaultPdfFile.fromJson(json);

      expect(file.fileId, 'mega-node-01');
      expect(file.name, 'Kontrak_Kerja.pdf');
      expect(file.size, 245760);
      expect(file.updatedAt, DateTime.parse('2026-11-20T03:00:00.000Z'));
      expect(file.isSigned, isFalse);
      expect(file.formattedSize, '240 KB');

      final largeFile = VaultPdfFile.fromJson(<String, dynamic>{
        ...json,
        'size': 1258291,
        'isSigned': true,
      });
      expect(largeFile.isSigned, isTrue);
      expect(largeFile.formattedSize, '1.2 MB');
    });

    test('SignaturePlacement.toJson matches PRD section 5 and validates ratios 0.0-1.0', () {
      final placement = SignaturePlacement(
        pageIndex: 0,
        xRatio: 0.62,
        yRatio: 0.78,
        widthRatio: 0.22,
        heightRatio: 0.08,
      );

      expect(placement.toJson(), <String, dynamic>{
        'pageIndex': 0,
        'xRatio': 0.62,
        'yRatio': 0.78,
        'widthRatio': 0.22,
        'heightRatio': 0.08,
      });

      expect(
        () => SignaturePlacement(
          pageIndex: -1,
          xRatio: 0.5,
          yRatio: 0.5,
          widthRatio: 0.2,
          heightRatio: 0.1,
        ),
        throwsArgumentError,
      );

      expect(
        () => SignaturePlacement(
          pageIndex: 0,
          xRatio: 1.2,
          yRatio: 0.5,
          widthRatio: 0.2,
          heightRatio: 0.1,
        ),
        throwsArgumentError,
      );

      expect(
        () => SignaturePlacement(
          pageIndex: 0,
          xRatio: 0.5,
          yRatio: 0.5,
          widthRatio: 0.0,
          heightRatio: 0.1,
        ),
        throwsArgumentError,
      );
    });
  });

  group('MyAcrobatApiClient', () {
    test('fetchFiles() parses { "files": [...] } into List<VaultPdfFile> and forwards search query', () async {
      RequestOptions? capturedOptions;
      final dio = Dio(BaseOptions(baseUrl: 'http://localhost:3000'));
      dio.httpClientAdapter = _RecordingHttpClientAdapter((options, _) async {
        capturedOptions = options;
        return ResponseBody.fromString(
          jsonEncode({
            'files': [
              {
                'fileId': 'f-1',
                'name': 'Surat_Tugas.pdf',
                'size': 102400,
                'updatedAt': '2026-11-20T01:00:00.000Z',
                'isSigned': false,
              },
              {
                'fileId': 'f-2',
                'name': 'Surat_Tugas_signed.pdf',
                'size': 112640,
                'updatedAt': '2026-11-20T02:00:00.000Z',
                'isSigned': true,
              },
            ],
          }),
          200,
          headers: {
            Headers.contentTypeHeader: [Headers.jsonContentType],
          },
        );
      });

      final client = MyAcrobatApiClient(dio: dio);
      final files = await client.fetchFiles(search: 'Surat');

      expect(capturedOptions?.method, 'GET');
      expect(capturedOptions?.path, '/api/files');
      expect(capturedOptions?.queryParameters, {'search': 'Surat'});
      expect(files, hasLength(2));
      expect(files[0].fileId, 'f-1');
      expect(files[0].isSigned, isFalse);
      expect(files[1].fileId, 'f-2');
      expect(files[1].isSigned, isTrue);
    });

    test('downloadPdfBytes() requests GET /api/files/:fileId/download and returns Uint8List', () async {
      RequestOptions? capturedOptions;
      final samplePdfBytes = Uint8List.fromList(utf8.encode('%PDF-1.7-mock'));

      final dio = Dio(BaseOptions(baseUrl: 'http://localhost:3000'));
      dio.httpClientAdapter = _RecordingHttpClientAdapter((options, _) async {
        capturedOptions = options;
        return ResponseBody.fromBytes(
          samplePdfBytes,
          200,
          headers: {
            Headers.contentTypeHeader: ['application/pdf'],
          },
        );
      });

      final client = MyAcrobatApiClient(dio: dio);
      final downloaded = await client.downloadPdfBytes('f-1');

      expect(capturedOptions?.method, 'GET');
      expect(capturedOptions?.path, '/api/files/f-1/download');
      expect(downloaded, equals(samplePdfBytes));
    });

    test('signDocument() sends data:image/png;base64,... and placements, then parses 201 SignDocumentResult', () async {
      RequestOptions? capturedOptions;
      Map<String, dynamic>? capturedBody;

      final pngBytes = Uint8List.fromList(<int>[
        0x89,
        0x50,
        0x4E,
        0x47,
        0x0D,
        0x0A,
        0x1A,
        0x0A,
      ]);

      final dio = Dio(BaseOptions(baseUrl: 'http://localhost:3000'));
      dio.httpClientAdapter = _RecordingHttpClientAdapter((options, reqBytes) async {
        capturedOptions = options;
        if (reqBytes != null && reqBytes.isNotEmpty) {
          capturedBody = jsonDecode(utf8.decode(reqBytes)) as Map<String, dynamic>;
        } else if (options.data is Map<String, dynamic>) {
          capturedBody = options.data as Map<String, dynamic>;
        }
        return ResponseBody.fromString(
          jsonEncode({
            'message': 'Dokumen berhasil ditandatangani dan disimpan ke Mega.nz',
            'sourceFileId': 'f-1',
            'signedFile': {
              'fileId': 'f-2',
              'name': 'Surat_Tugas_signed.pdf',
              'size': 115000,
              'updatedAt': '2026-11-20T03:30:00.000Z',
              'isSigned': true,
            },
          }),
          201,
          headers: {
            Headers.contentTypeHeader: [Headers.jsonContentType],
          },
        );
      });

      final client = MyAcrobatApiClient(dio: dio);
      final SignDocumentResult result = await client.signDocument(
        fileId: 'f-1',
        signaturePngBytes: pngBytes,
        placements: [
          SignaturePlacement(
            pageIndex: 0,
            xRatio: 0.62,
            yRatio: 0.78,
            widthRatio: 0.22,
            heightRatio: 0.08,
          ),
        ],
      );

      expect(capturedOptions?.method, 'POST');
      expect(capturedOptions?.path, '/api/files/f-1/sign');
      expect(
        capturedBody?['signatureImageBase64'],
        'data:image/png;base64,${base64Encode(pngBytes)}',
      );
      expect(capturedBody?['placements'], [
        {
          'pageIndex': 0,
          'xRatio': 0.62,
          'yRatio': 0.78,
          'widthRatio': 0.22,
          'heightRatio': 0.08,
        },
      ]);

      expect(result.sourceFileId, 'f-1');
      expect(result.signedFile.fileId, 'f-2');
      expect(result.signedFile.name, 'Surat_Tugas_signed.pdf');
      expect(result.signedFile.isSigned, isTrue);
    });

    test('MyAcrobatApiClient defaults baseUrl to AgriSign production server', () {
      final client = MyAcrobatApiClient();
      expect(client.baseUrl, 'https://syncro.saraswanti.co.id/agrisign');
    });
  });
}

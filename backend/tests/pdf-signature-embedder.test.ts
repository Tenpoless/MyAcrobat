import { describe, expect, it } from 'vitest';
import { PDFDocument } from 'pdf-lib';
import {
  InvalidSignaturePlacementError,
  computePdfDrawBox,
  embedSignatureIntoPdf,
} from '../src/pdf/pdf-signature-embedder.js';

// Valid 1x1 transparent PNG in base64
const TRANSPARENT_1X1_PNG_BASE64 =
  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNk+M9QDwADhgGAWjR9awAAAABJRU5ErkJggg==';

async function createSampleTwoPagePdf(): Promise<Uint8Array> {
  const doc = await PDFDocument.create();
  doc.addPage([600, 800]);
  doc.addPage([600, 800]);
  return doc.save();
}

describe('computePdfDrawBox (top-left UI ratio -> bottom-left PDF points)', () => {
  it('converts top-left ratio coordinates to exact bottom-left PDF coordinates', () => {
    const box = computePdfDrawBox(
      { pageWidth: 600, pageHeight: 800 },
      { xRatio: 0.5, yRatio: 0.75, widthRatio: 0.2, heightRatio: 0.1 }
    );

    expect(box).toEqual({
      x: 300,
      y: 120,
      width: 120,
      height: 80,
    });
  });
});

describe('embedSignatureIntoPdf', () => {
  it('embeds transparent PNG into target PDF page(s) and returns valid PDF bytes', async () => {
    const sourcePdf = await createSampleTwoPagePdf();

    const signedBytes = await embedSignatureIntoPdf({
      pdfBytes: sourcePdf,
      signaturePngBase64OrBytes: `data:image/png;base64,${TRANSPARENT_1X1_PNG_BASE64}`,
      placements: [
        {
          pageIndex: 0,
          xRatio: 0.5,
          yRatio: 0.75,
          widthRatio: 0.2,
          heightRatio: 0.1,
        },
        {
          pageIndex: 1,
          xRatio: 0.62,
          yRatio: 0.78,
          widthRatio: 0.22,
          heightRatio: 0.08,
        },
      ],
    });

    expect(signedBytes).toBeInstanceOf(Uint8Array);
    expect(signedBytes.byteLength).toBeGreaterThan(sourcePdf.byteLength);

    const loadedDoc = await PDFDocument.load(signedBytes);
    expect(loadedDoc.getPageCount()).toBe(2);
  });

  it('throws InvalidSignaturePlacementError when placements are empty, pageIndex is out of range, or ratios are outside 0.0-1.0', async () => {
    const sourcePdf = await createSampleTwoPagePdf();

    await expect(
      embedSignatureIntoPdf({
        pdfBytes: sourcePdf,
        signaturePngBase64OrBytes: TRANSPARENT_1X1_PNG_BASE64,
        placements: [],
      })
    ).rejects.toThrow(InvalidSignaturePlacementError);

    await expect(
      embedSignatureIntoPdf({
        pdfBytes: sourcePdf,
        signaturePngBase64OrBytes: TRANSPARENT_1X1_PNG_BASE64,
        placements: [
          {
            pageIndex: 2,
            xRatio: 0.5,
            yRatio: 0.5,
            widthRatio: 0.2,
            heightRatio: 0.1,
          },
        ],
      })
    ).rejects.toThrow(InvalidSignaturePlacementError);

    await expect(
      embedSignatureIntoPdf({
        pdfBytes: sourcePdf,
        signaturePngBase64OrBytes: TRANSPARENT_1X1_PNG_BASE64,
        placements: [
          {
            pageIndex: 0,
            xRatio: -0.1,
            yRatio: 0.5,
            widthRatio: 0.2,
            heightRatio: 0.1,
          },
        ],
      })
    ).rejects.toThrow(InvalidSignaturePlacementError);

    await expect(
      embedSignatureIntoPdf({
        pdfBytes: sourcePdf,
        signaturePngBase64OrBytes: TRANSPARENT_1X1_PNG_BASE64,
        placements: [
          {
            pageIndex: 0,
            xRatio: 0.5,
            yRatio: 0.5,
            widthRatio: 1.2,
            heightRatio: 0.1,
          },
        ],
      })
    ).rejects.toThrow(InvalidSignaturePlacementError);
  });
});

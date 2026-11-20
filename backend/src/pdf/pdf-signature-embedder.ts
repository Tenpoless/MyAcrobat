import { PDFDocument } from 'pdf-lib';

export interface SignaturePlacementInput {
  pageIndex: number;
  xRatio: number;
  yRatio: number;
  widthRatio: number;
  heightRatio: number;
}

export interface PdfDrawBox {
  x: number;
  y: number;
  width: number;
  height: number;
}

export class InvalidSignaturePlacementError extends Error {
  constructor(message: string) {
    super(message);
    this.name = 'InvalidSignaturePlacementError';
  }
}

export function computePdfDrawBox(
  pageSize: { pageWidth: number; pageHeight: number },
  placement: Omit<SignaturePlacementInput, 'pageIndex'>
): PdfDrawBox {
  const { pageWidth, pageHeight } = pageSize;
  const width = placement.widthRatio * pageWidth;
  const height = placement.heightRatio * pageHeight;
  const x = placement.xRatio * pageWidth;
  const y = pageHeight - placement.yRatio * pageHeight - height;

  return { x, y, width, height };
}

function decodePngBytes(input: string | Uint8Array): Uint8Array {
  if (input instanceof Uint8Array) {
    if (input.byteLength === 0) {
      throw new InvalidSignaturePlacementError('Gambar tanda tangan PNG tidak boleh kosong');
    }
    return input;
  }

  const trimmed = input.trim();
  if (!trimmed) {
    throw new InvalidSignaturePlacementError('Gambar tanda tangan PNG tidak boleh kosong');
  }

  const base64Payload = trimmed.replace(/^data:image\/png;base64,/i, '');
  return new Uint8Array(Buffer.from(base64Payload, 'base64'));
}

function validateRatio(name: string, value: number, allowZero = true): void {
  const minValid = allowZero ? value >= 0 : value > 0;
  if (!Number.isFinite(value) || !minValid || value > 1) {
    throw new InvalidSignaturePlacementError(
      `Rasio ${name} (${value}) tidak valid; harus berada dalam rentang ${allowZero ? '0.0' : '> 0.0'} hingga 1.0`
    );
  }
}

export async function embedSignatureIntoPdf(params: {
  pdfBytes: Uint8Array;
  signaturePngBase64OrBytes: string | Uint8Array;
  placements: SignaturePlacementInput[];
}): Promise<Uint8Array> {
  const { pdfBytes, signaturePngBase64OrBytes, placements } = params;

  if (!Array.isArray(placements) || placements.length === 0) {
    throw new InvalidSignaturePlacementError(
      'Minimal satu posisi tanda tangan (placements) wajib dikirim'
    );
  }

  const pngBytes = decodePngBytes(signaturePngBase64OrBytes);
  const pdfDoc = await PDFDocument.load(pdfBytes);
  const pages = pdfDoc.getPages();

  for (const placement of placements) {
    if (
      !Number.isInteger(placement.pageIndex) ||
      placement.pageIndex < 0 ||
      placement.pageIndex >= pages.length
    ) {
      throw new InvalidSignaturePlacementError(
        `pageIndex (${placement.pageIndex}) berada di luar jumlah halaman PDF (0..${pages.length - 1})`
      );
    }

    validateRatio('xRatio', placement.xRatio, true);
    validateRatio('yRatio', placement.yRatio, true);
    validateRatio('widthRatio', placement.widthRatio, false);
    validateRatio('heightRatio', placement.heightRatio, false);
  }

  const embeddedPng = await pdfDoc.embedPng(pngBytes);

  for (const placement of placements) {
    const page = pages[placement.pageIndex];
    const { width: pageWidth, height: pageHeight } = page.getSize();
    const box = computePdfDrawBox({ pageWidth, pageHeight }, placement);

    page.drawImage(embeddedPng, {
      x: box.x,
      y: box.y,
      width: box.width,
      height: box.height,
    });
  }

  return pdfDoc.save();
}

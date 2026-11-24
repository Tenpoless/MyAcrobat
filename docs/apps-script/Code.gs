/**
 * AgriDocs Google Drive bridge (Web App).
 * Deploy: Execute as "Me", access "Anyone". Isi SECRET sama dengan
 * AGRISIGN_GOOGLE_APPS_SCRIPT_SECRET di .env server.
 */
const SECRET = 'AgriSign2026!';

function doGet(e) {
  try {
    const p = e.parameter || {};
    checkSecret_(p.secret);
    if (p.action === 'list') return json_(listFolder_(p.folderId));
    if (p.action === 'download') return json_(download_(p.fileId));
    throw new Error('Action tidak dikenal: ' + p.action);
  } catch (err) {
    return json_({ error: String(err.message || err) });
  }
}

function doPost(e) {
  try {
    const body = JSON.parse(e.postData.contents);
    checkSecret_(body.secret);
    if (body.action === 'upload') return json_(upload_(body));
    throw new Error('Action tidak dikenal: ' + body.action);
  } catch (err) {
    return json_({ error: String(err.message || err) });
  }
}

function checkSecret_(secret) {
  if (secret !== SECRET) throw new Error('Secret tidak valid');
}

function json_(obj) {
  return ContentService.createTextOutput(JSON.stringify(obj))
    .setMimeType(ContentService.MimeType.JSON);
}

// Kosong atau 'root' = My Drive.
function folder_(folderId) {
  return !folderId || folderId === 'root'
    ? DriveApp.getRootFolder()
    : DriveApp.getFolderById(folderId);
}

function listFolder_(folderId) {
  const parent = folder_(folderId);
  const folders = [];
  const subs = parent.getFolders();
  while (subs.hasNext()) {
    const f = subs.next();
    folders.push({
      id: f.getId(),
      name: f.getName(),
      modifiedTime: f.getLastUpdated().toISOString(),
    });
  }
  const files = [];
  const pdfs = parent.getFilesByType(MimeType.PDF);
  while (pdfs.hasNext()) {
    const f = pdfs.next();
    files.push({
      id: f.getId(),
      name: f.getName(),
      size: f.getSize(),
      modifiedTime: f.getLastUpdated().toISOString(),
    });
  }
  return { folders: folders, files: files };
}

function download_(fileId) {
  const blob = DriveApp.getFileById(fileId).getBlob();
  return { base64: Utilities.base64Encode(blob.getBytes()) };
}

function upload_(body) {
  const blob = Utilities.newBlob(
    Utilities.base64Decode(body.base64), MimeType.PDF, body.fileName);
  const f = folder_(body.folderId).createFile(blob);
  return {
    id: f.getId(),
    name: f.getName(),
    size: f.getSize(),
    modifiedTime: f.getLastUpdated().toISOString(),
  };
}

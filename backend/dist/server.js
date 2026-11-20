import 'dotenv/config';
import { loadConfig } from './config.js';
import { buildApp } from './app.js';
import { MegaCloudVaultAdapter } from './vault/cloud-vault.js';
import { PostgresSyncroUserDirectory } from './auth/syncro-user-directory.js';
const config = loadConfig();
const vault = new MegaCloudVaultAdapter({
    email: config.megaEmail,
    password: config.megaPassword,
    rootFolder: config.megaRootFolder,
});
const userDirectory = new PostgresSyncroUserDirectory({
    connectionString: config.syncroDbUrl,
    publicStorageDir: config.syncroPublicStorageDir,
});
const app = buildApp({
    logger: true,
    vault,
    userDirectory,
    authTokenSecret: config.authTokenSecret,
    publicWebDir: config.publicWebDir,
});
app.listen({ port: config.port, host: config.host }).catch((err) => {
    app.log.error(err);
    process.exit(1);
});

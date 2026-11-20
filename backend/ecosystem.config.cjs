module.exports = {
  apps: [
    {
      name: 'myacrobat-backend',
      script: './dist/server.js',
      cwd: __dirname,
      instances: 1,
      autorestart: true,
      watch: false,
      max_memory_restart: '512M',
      env: {
        NODE_ENV: 'production',
        PORT: 3000,
        HOST: '0.0.0.0',
        PUBLIC_WEB_DIR: './public',
      },
    },
  ],
};

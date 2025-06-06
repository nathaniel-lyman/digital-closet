# API Keys Setup Guide

This guide explains how to securely manage API keys in the Digital Closet app.

## Required API Keys

1. **OpenAI API Key** - For clothing analysis
2. **Remove.bg API Key** - For background removal

## Method 1: Xcode Environment Variables (Recommended)

### Setup Steps:

1. In Xcode, click on the scheme selector (next to the device selector)
2. Select "Edit Scheme..."
3. Select "Run" from the left sidebar
4. Click on the "Arguments" tab
5. In "Environment Variables", click the "+" button
6. Add the following:
   - Name: `OPENAI_KEY`, Value: `your-openai-api-key`
   - Name: `REMBG_KEY`, Value: `your-rembg-api-key`

### Advantages:
- Keys never exist in source code
- Different keys for different schemes (Debug/Release)
- Keys are stored in your Xcode workspace (not in git)

## Method 2: SecureConfig.swift File

1. Copy the template:
   ```bash
   cp Configuration/SecureConfig.swift.template Configuration/SecureConfig.swift
   ```

2. Edit `SecureConfig.swift` and add your keys:
   ```swift
   struct SecureConfig {
       static let remBgKey = "your-actual-rembg-key"
       static let openAIKey = "your-actual-openai-key"
   }
   ```

3. **Important**: SecureConfig.swift is gitignored. Never commit it!

## Method 3: Using a Config.plist (Alternative)

For a more flexible approach, you can use a plist file:

1. Create `Config.plist` in your project
2. Add it to .gitignore
3. Structure:
   ```xml
   <?xml version="1.0" encoding="UTF-8"?>
   <!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
   <plist version="1.0">
   <dict>
       <key>OPENAI_KEY</key>
       <string>your-openai-key</string>
       <key>REMBG_KEY</key>
       <string>your-rembg-key</string>
   </dict>
   </plist>
   ```

## Security Best Practices

1. **Never commit API keys to git**
2. **Use different keys for development and production**
3. **Rotate keys regularly**
4. **Use environment-specific configurations**
5. **Consider using a secrets management service for production**

## Getting API Keys

### OpenAI API Key:
1. Go to https://platform.openai.com/api-keys
2. Create an account or sign in
3. Generate a new API key
4. Copy the key (you won't be able to see it again)

### Remove.bg API Key:
1. Go to https://www.remove.bg/users/sign_up
2. Create an account
3. Go to https://www.remove.bg/api
4. Get your API key

## Troubleshooting

If you see errors about missing API keys:
1. Check that environment variables are set in your scheme
2. Verify SecureConfig.swift exists and contains keys
3. Make sure you're running the correct scheme
4. Check the console for specific error messages

## CI/CD Considerations

For CI/CD pipelines:
- Use environment variables in your CI service
- Never store keys in your repository
- Use secure environment variable storage in your CI/CD platform
- Consider using Apple's App Store Connect API for automated deployments 
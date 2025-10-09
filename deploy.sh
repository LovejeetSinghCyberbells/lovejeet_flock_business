#!/bin/bash

# QR Code Redirect Deployment Script
# This script helps deploy the download.html file to GitHub Pages

echo "🚀 QR Code Redirect Deployment Script"
echo "======================================"

# Check if git is installed
if ! command -v git &> /dev/null; then
    echo "❌ Git is not installed. Please install git first."
    exit 1
fi

# Create a temporary directory for deployment
TEMP_DIR="temp_deploy_$(date +%s)"
mkdir $TEMP_DIR
cd $TEMP_DIR

echo "📁 Creating deployment directory..."

# Copy the HTML file
cp ../web/download.html .

# Create a simple index.html that redirects to download.html
cat > index.html << 'EOF'
<!DOCTYPE html>
<html>
<head>
    <meta charset="UTF-8">
    <title>Flock App</title>
    <meta http-equiv="refresh" content="0; url=download.html">
</head>
<body>
    <p>Redirecting to Flock app download...</p>
    <script>
        window.location.href = 'download.html';
    </script>
</body>
</html>
EOF

# Initialize git repository
git init
git add .
git commit -m "Initial commit: QR code redirect page"

echo ""
echo "✅ Files prepared for deployment"
echo ""
echo "📋 Next steps:"
echo "1. Create a new GitHub repository"
echo "2. Run these commands in the $TEMP_DIR directory:"
echo "   git remote add origin https://github.com/YOUR_USERNAME/YOUR_REPO_NAME.git"
echo "   git branch -M main"
echo "   git push -u origin main"
echo ""
echo "3. Go to your repository Settings > Pages"
echo "4. Select 'Deploy from a branch' and choose 'main'"
echo "5. Your URL will be: https://YOUR_USERNAME.github.io/YOUR_REPO_NAME/download.html"
echo ""
echo "6. Update the fallback URLs in your Flutter app:"
echo "   - lib/HomeScreen.dart"
echo "   - lib/venue.dart"
echo "   Replace 'https://getflock.io/download.html' with your GitHub Pages URL"
echo ""
echo "📁 Deployment files are ready in: $TEMP_DIR"
echo "💡 You can also manually upload download.html to any web hosting service" 
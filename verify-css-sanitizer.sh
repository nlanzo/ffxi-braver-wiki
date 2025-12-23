#!/bin/bash
# Script to verify that wikimedia/css-sanitizer is installed
# This is required for TemplateStyles extension to work properly

set -e

echo "Checking for wikimedia/css-sanitizer package..."

if [ -d "vendor/wikimedia/css-sanitizer" ]; then
    echo "✓ css-sanitizer is installed"
    echo "  Location: vendor/wikimedia/css-sanitizer"
    ls -la vendor/wikimedia/css-sanitizer/src/ | head -3
    exit 0
else
    echo "✗ css-sanitizer is NOT installed"
    echo ""
    echo "To install it, run:"
    echo "  composer require wikimedia/css-sanitizer:^5.5.0 --no-dev --optimize-autoloader"
    echo ""
    echo "Or ensure TemplateStyles/composer.json is included in composer merge-plugin"
    exit 1
fi


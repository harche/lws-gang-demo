#!/bin/bash

echo "===================================================="
echo "Cleanup Script"
echo "===================================================="
echo ""

echo "⚠️  This will delete the lws-gang-demo kind cluster"
read -p "Are you sure? (y/n) " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "Cleanup cancelled"
    exit 0
fi

echo ""
echo "🧹 Deleting kind cluster..."
kind delete cluster --name lws-gang-demo

echo "✅ Cleanup complete!"

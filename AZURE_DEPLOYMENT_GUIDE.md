# Azure Function Deployment Guide

## ✅ Your Azure Function is Ready!

The Azure Function code has been successfully compiled and is ready for deployment. Here's how to deploy it:

## 📋 Prerequisites

1. **Azure Account**: Sign up at https://portal.azure.com (free $200 credit)
2. **Azure CLI**: Install from https://docs.microsoft.com/en-us/cli/azure/install-azure-cli
3. **Azure Functions Core Tools**: Install from https://docs.microsoft.com/en-us/azure/azure-functions/functions-run-local

## 🚀 Deployment Steps

### Step 1: Create Azure Resources

#### 1.1 Document Intelligence Resource
```bash
# Login to Azure
az login

# Create resource group
az group create --name invoice-processing-rg --location "East US"

# Create Document Intelligence resource
az cognitiveservices account create \
  --name invoice-reader-docint \
  --resource-group invoice-processing-rg \
  --kind FormRecognizer \
  --sku F0 \
  --location "East US"

# Get Document Intelligence keys
az cognitiveservices account keys list \
  --name invoice-reader-docint \
  --resource-group invoice-processing-rg
```

#### 1.2 Function App
```bash
# Create storage account (required for Function App)
az storage account create \
  --name invoiceprocessorstorage \
  --resource-group invoice-processing-rg \
  --location "East US" \
  --sku Standard_LRS

# Create Function App
az functionapp create \
  --resource-group invoice-processing-rg \
  --consumption-plan-location "East US" \
  --runtime dotnet-isolated \
  --runtime-version 8 \
  --functions-version 4 \
  --name invoice-processor-func \
  --storage-account invoiceprocessorstorage
```

### Step 2: Configure Environment Variables

```bash
# Set Document Intelligence configuration
az functionapp config appsettings set \
  --name invoice-processor-func \
  --resource-group invoice-processing-rg \
  --settings \
  "DOCUMENT_INTELLIGENCE_ENDPOINT=YOUR_ENDPOINT_HERE" \
  "DOCUMENT_INTELLIGENCE_KEY=YOUR_KEY_HERE" \
  "FIREBASE_PROJECT_ID=invoicereader-70363"
```

### Step 3: Deploy Function

#### Option A: Using Azure Functions Core Tools
```bash
# Navigate to function directory
cd "/Users/arul/Documents/flutter app/invoicereport/azure-function"

# Deploy to Azure
func azure functionapp publish invoice-processor-func
```

#### Option B: Using VS Code
1. Install **Azure Functions** extension
2. Open the `/azure-function/` folder
3. Press `F1` → "Azure Functions: Deploy to Function App"
4. Select your Function App

### Step 4: Test Deployment

```bash
# Get Function App URL
az functionapp show \
  --name invoice-processor-func \
  --resource-group invoice-processing-rg \
  --query "defaultHostName" \
  --output tsv
```

Your Function will be available at:
`https://invoice-processor-func.azurewebsites.net/api/ProcessInvoice`

### Step 5: Update Flutter App

Update the base URL in your Flutter app:

```dart
// In lib/services/azure_function_service.dart
static const String _defaultBaseUrl = 'https://invoice-processor-func.azurewebsites.net/api';
```

## 🧪 Testing the Function

### Test with curl:
```bash
curl -X POST "https://invoice-processor-func.azurewebsites.net/api/ProcessInvoice" \
  -H "Content-Type: application/json" \
  -d '{
    "invoiceId": "test-123",
    "tenantId": "test-tenant",
    "imageUrl": "https://example.com/invoice.jpg"
  }'
```

## 🔍 Monitoring & Debugging

### View Logs:
```bash
# Stream live logs
az webapp log tail \
  --name invoice-processor-func \
  --resource-group invoice-processing-rg
```

### Azure Portal:
1. Go to your Function App in Azure Portal
2. Click "Functions" → "ProcessInvoice"
3. Click "Monitor" to view execution logs
4. Use "Test/Run" to test the function directly

## 💰 Cost Monitoring

### Free Tier Limits:
- **Document Intelligence**: 500 pages/month FREE
- **Azure Functions**: 1M executions/month FREE
- **Storage**: 5GB FREE

### Monitor Usage:
- Check Azure Portal → Cost Management
- Set up billing alerts for peace of mind

## 🔧 Configuration Files

### Required Environment Variables:
- `DOCUMENT_INTELLIGENCE_ENDPOINT`: Your Document Intelligence endpoint
- `DOCUMENT_INTELLIGENCE_KEY`: Your Document Intelligence key
- `FIREBASE_PROJECT_ID`: Your Firebase project ID (invoicereader-70363)

### Firebase Authentication:
For production, you'll need to add Firebase service account credentials for Firestore access.

## 🚨 Troubleshooting

### Common Issues:

1. **Function not found**: Check function name and URL
2. **Authentication errors**: Verify environment variables
3. **Firestore errors**: Check Firebase project settings
4. **Timeout errors**: Increase function timeout in Azure Portal

### Debug Steps:
1. Check Azure Portal logs
2. Verify environment variables
3. Test with simple request
4. Check CORS settings if needed

## 🎉 Success!

Once deployed, your invoice scanning app will have:
- ✅ Real Azure OCR processing
- ✅ Automatic data extraction
- ✅ Firestore integration
- ✅ Production-ready architecture

Your app will extract:
- Vendor information
- Invoice numbers and dates
- Line items with quantities and prices
- Total amounts and taxes
- All structured data for reporting

Ready to process real invoices with Azure Document Intelligence! 🎯

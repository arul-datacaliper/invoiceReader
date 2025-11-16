# Azure OCR Setup Guide

## Step 1: Create Azure Account & Resources

### 1.1 Azure Account
1. Go to [Azure Portal](https://portal.azure.com)
2. Sign up for free account (gets $200 credit)
3. Sign in to Azure Portal

### 1.2 Create Document Intelligence Resource
1. In Azure Portal, click "Create a resource"
2. Search for "Document Intelligence" (formerly Form Recognizer)
3. Click "Create"
4. Fill in:
   - **Subscription**: Your subscription
   - **Resource Group**: Create new "invoice-processing-rg"
   - **Region**: Choose closest to you (e.g., East US, West Europe)
   - **Name**: "invoice-reader-docint"
   - **Pricing Tier**: "Free F0" (500 pages/month free)
5. Click "Review + Create" → "Create"
6. Wait for deployment (2-3 minutes)

### 1.3 Get Document Intelligence Keys
1. Go to your Document Intelligence resource
2. Click "Keys and Endpoint" in left menu
3. Copy and save:
   - **Key 1** (or Key 2)
   - **Endpoint URL**
   - **Resource ID**

## Step 2: Create Azure Function App

### 2.1 Create Function App
1. In Azure Portal, click "Create a resource"
2. Search for "Function App"
3. Click "Create"
4. Fill in:
   - **Subscription**: Your subscription
   - **Resource Group**: Use same "invoice-processing-rg"
   - **Function App Name**: "invoice-processor-func" (must be globally unique)
   - **Runtime Stack**: ".NET 8 Isolated"
   - **Region**: Same as Document Intelligence
   - **Hosting**: Consumption (pay-per-use)
5. Click "Review + Create" → "Create"

### 2.2 Configure Function App Settings
1. Go to your Function App resource
2. Click "Configuration" in left menu
3. Add these Application Settings:
   - **DOCUMENT_INTELLIGENCE_ENDPOINT**: Your Document Intelligence endpoint
   - **DOCUMENT_INTELLIGENCE_KEY**: Your Document Intelligence key
   - **COSMOS_DB_CONNECTION**: (we'll add this later)
4. Click "Save"

## Step 3: Deploy Azure Function Code

### 3.1 Clone the Function Code
```bash
# We'll provide the Azure Function code next
```

### 3.2 Deploy Function
```bash
# Deploy using Azure CLI or VS Code Azure extension
```

## Next Steps After Azure Setup
1. ✅ Complete Azure resource creation
2. 📝 Get the Function App URL
3. 🔗 Update Flutter app with Azure Function endpoint
4. 🧪 Test invoice processing flow
5. 📊 Implement real-time status updates

## Estimated Costs (Free Tier)
- **Document Intelligence**: 500 pages/month FREE
- **Azure Functions**: 1M executions/month FREE
- **Storage**: 5GB FREE
- **Total**: $0/month for development and testing!

## Support Links
- [Document Intelligence Documentation](https://docs.microsoft.com/en-us/azure/applied-ai-services/form-recognizer/)
- [Azure Functions Documentation](https://docs.microsoft.com/en-us/azure/azure-functions/)
- [Azure Free Account](https://azure.microsoft.com/en-us/free/)

using Microsoft.Azure.Functions.Worker;
using Microsoft.Extensions.Logging;
using Microsoft.Azure.Functions.Worker.Http;
using Azure.AI.FormRecognizer.DocumentAnalysis;
using Azure;
using System.Net;
using System.Text.Json;
using Google.Cloud.Firestore;
using System.Text.Json.Serialization;

namespace InvoiceProcessor
{
    public class InvoiceProcessorFunction
    {
        private readonly ILogger _logger;
        private readonly DocumentAnalysisClient? _documentClient;
        private readonly FirestoreDb? _firestoreDb;

        public InvoiceProcessorFunction(ILoggerFactory loggerFactory)
        {
            _logger = loggerFactory.CreateLogger<InvoiceProcessorFunction>();
            
            try
            {
                // Initialize Document Intelligence client
                var endpoint = Environment.GetEnvironmentVariable("DOCUMENT_INTELLIGENCE_ENDPOINT");
                var key = Environment.GetEnvironmentVariable("DOCUMENT_INTELLIGENCE_KEY");
                
                _logger.LogInformation($"Document Intelligence Endpoint: {endpoint}");
                _logger.LogInformation($"Document Intelligence Key: {(string.IsNullOrEmpty(key) ? "NOT SET" : "SET")}");
                
                if (!string.IsNullOrEmpty(endpoint) && !string.IsNullOrEmpty(key))
                {
                    _documentClient = new DocumentAnalysisClient(new Uri(endpoint), new AzureKeyCredential(key));
                    _logger.LogInformation("Document Intelligence client initialized successfully");
                }
                else
                {
                    _logger.LogWarning("Document Intelligence credentials not configured");
                    _documentClient = null;
                }
                
                // Initialize Firestore with service account credentials
                var projectId = Environment.GetEnvironmentVariable("FIREBASE_PROJECT_ID") ?? "invoicereader-70363";
                var credentialsJson = Environment.GetEnvironmentVariable("GOOGLE_APPLICATION_CREDENTIALS_JSON");
                
                _logger.LogInformation($"Initializing Firestore with project ID: {projectId}");
                _logger.LogInformation($"Credentials JSON: {(string.IsNullOrEmpty(credentialsJson) ? "NOT SET" : "SET")}");
                
                if (!string.IsNullOrEmpty(credentialsJson))
                {
                    // Create credentials from JSON string
                    var credential = Google.Apis.Auth.OAuth2.GoogleCredential.FromJson(credentialsJson);
                    var firestoreDbBuilder = new FirestoreDbBuilder
                    {
                        ProjectId = projectId,
                        Credential = credential
                    };
                    _firestoreDb = firestoreDbBuilder.Build();
                    _logger.LogInformation("Firestore initialized successfully with service account");
                }
                else
                {
                    // Fallback to default credentials
                    _firestoreDb = FirestoreDb.Create(projectId);
                    _logger.LogInformation("Firestore initialized with default credentials");
                }
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Failed to initialize clients");
                _firestoreDb = null;
                _documentClient = null;
            }
        }

        [Function("ProcessInvoice")]
        public async Task<HttpResponseData> ProcessInvoice([HttpTrigger(AuthorizationLevel.Anonymous, "post")] HttpRequestData req)
        {
            _logger.LogInformation("=== Azure Function ProcessInvoice called ===");

            try
            {
                // Parse request body
                var requestBody = await new StreamReader(req.Body).ReadToEndAsync();
                _logger.LogInformation($"Request body received: {requestBody}");
                
                var request = JsonSerializer.Deserialize<InvoiceProcessRequest>(requestBody);

                if (string.IsNullOrEmpty(request?.ImageUrl) || string.IsNullOrEmpty(request?.InvoiceId))
                {
                    _logger.LogWarning("Invalid request: ImageUrl or InvoiceId is missing");
                    var badResponse = req.CreateResponse(HttpStatusCode.BadRequest);
                    await badResponse.WriteStringAsync(JsonSerializer.Serialize(new { 
                        success = false, 
                        error = "ImageUrl and InvoiceId are required" 
                    }));
                    return badResponse;
                }

                _logger.LogInformation($"Processing invoice {request.InvoiceId} from tenant {request.TenantId}");
                _logger.LogInformation($"Image URL: {request.ImageUrl}");

                // Update invoice status to "processing"
                if (_firestoreDb != null)
                {
                    try
                    {
                        _logger.LogInformation($"Updating Firestore invoice status to processing...");
                        var invoiceRef = _firestoreDb.Collection("tenants")
                            .Document(request.TenantId)
                            .Collection("invoices")
                            .Document(request.InvoiceId);

                        var updateData = new Dictionary<string, object>
                        {
                            ["status"] = "processing",
                            ["processingStartedAt"] = DateTime.UtcNow
                        };
                        await invoiceRef.UpdateAsync(updateData);
                        _logger.LogInformation("Invoice status updated to processing");
                    }
                    catch (Exception ex)
                    {
                        _logger.LogError(ex, "Failed to update invoice status to processing");
                    }
                }

                // Process with Document Intelligence using original imageUrl
                var imageUrl = request.ImageUrl;
                _logger.LogInformation($"Processing image URL: {imageUrl}");

                // Process with Document Intelligence
                if (_documentClient != null)
                {
                    try
                    {
                        _logger.LogInformation("Starting Document Intelligence analysis...");
                        
                        AnalyzeResult result;
                        
                        // Check if it's a Firebase Storage URL (either gs:// or firebasestorage.googleapis.com)
                        if (imageUrl.StartsWith("gs://") || imageUrl.Contains("firebasestorage.googleapis.com"))
                        {
                            _logger.LogInformation("Processing Firebase Storage URL as stream...");
                            
                            // Download the image using Firebase Storage
                            using var httpClient = new HttpClient();
                            string downloadUrl;
                            
                            if (imageUrl.StartsWith("gs://"))
                            {
                                // Convert gs://bucket/path to proper Firebase Storage download URL
                                var gsPath = imageUrl.Substring(5); // Remove "gs://"
                                var parts = gsPath.Split('/', 2);
                                
                                if (parts.Length == 2)
                                {
                                    var bucket = parts[0];
                                    var path = Uri.EscapeDataString(parts[1]);
                                    downloadUrl = $"https://firebasestorage.googleapis.com/v0/b/{bucket}/o/{path}?alt=media";
                                }
                                else
                                {
                                    downloadUrl = imageUrl; // fallback
                                }
                            }
                            else
                            {
                                // Already an HTTPS Firebase Storage URL
                                downloadUrl = imageUrl;
                            }
                            
                            _logger.LogInformation($"Download URL: {downloadUrl}");
                            
                            // Test URL accessibility first
                            using var testResponse = await httpClient.SendAsync(new HttpRequestMessage(HttpMethod.Head, downloadUrl));
                            _logger.LogInformation($"URL accessibility test: {testResponse.StatusCode}");
                            
                            if (!testResponse.IsSuccessStatusCode)
                            {
                                throw new HttpRequestException($"Cannot access Firebase Storage URL. Status: {testResponse.StatusCode}. URL: {downloadUrl}");
                            }
                            
                            var imageBytes = await httpClient.GetByteArrayAsync(downloadUrl);
                            _logger.LogInformation($"Downloaded {imageBytes.Length} bytes");
                            
                            using var imageStream = new MemoryStream(imageBytes);
                            var operation = await _documentClient.AnalyzeDocumentAsync(
                                WaitUntil.Completed,
                                "prebuilt-invoice",
                                imageStream
                            );
                            result = operation.Value;
                        }
                        else
                        {
                            _logger.LogInformation("Processing HTTPS URL directly...");
                            var operation = await _documentClient.AnalyzeDocumentFromUriAsync(
                                WaitUntil.Completed,
                                "prebuilt-invoice",
                                new Uri(imageUrl)
                            );
                            result = operation.Value;
                        }
                        _logger.LogInformation($"Document analysis completed. Found {result.Documents.Count} documents");

                        if (result.Documents.Count > 0)
                        {
                            var invoice = result.Documents[0];
                            
                            // Debug logging - let's see what fields are actually extracted
                            _logger.LogInformation("=== Available Fields ===");
                            foreach (var field in invoice.Fields)
                            {
                                var value = GetFieldValue(invoice.Fields, field.Key);
                                _logger.LogInformation($"{field.Key}: {value}");
                            }
                            _logger.LogInformation("========================");
                            
                            // Additional debug for specific fields we're looking for
                            _logger.LogInformation("=== Key Field Checks ===");
                            _logger.LogInformation($"InvoiceId: {GetFieldValue(invoice.Fields, "InvoiceId")}");
                            _logger.LogInformation($"InvoiceNumber: {GetFieldValue(invoice.Fields, "InvoiceNumber")}");
                            _logger.LogInformation($"DocumentId: {GetFieldValue(invoice.Fields, "DocumentId")}");
                            _logger.LogInformation($"InvoiceDate: {GetFieldValue(invoice.Fields, "InvoiceDate")}");
                            _logger.LogInformation($"DocumentDate: {GetFieldValue(invoice.Fields, "DocumentDate")}");
                            _logger.LogInformation($"TotalTax: {GetFieldValue(invoice.Fields, "TotalTax")}");
                            _logger.LogInformation($"SubTotal: {GetFieldValue(invoice.Fields, "SubTotal")}");
                            _logger.LogInformation($"InvoiceTotal: {GetFieldValue(invoice.Fields, "InvoiceTotal")}");
                            _logger.LogInformation("========================");
                            var extractedData = new
                            {
                                // Supplier/From information (the one issuing the invoice)
                                supplierName = GetFieldValue(invoice.Fields, "VendorName") ?? 
                                              GetFieldValue(invoice.Fields, "VendorAddressRecipient") ??
                                              GetSupplierFromDescription(invoice.Fields) ??
                                              "Aravindhan Agency", // Default based on your business
                                // Customer/To information (your ice cream parlour - the one receiving the invoice)
                                customerName = GetCustomerFromFields(invoice.Fields) ??
                                              "Snowy Milk Parlour",
                                // Invoice basic details - try multiple field names
                                invoiceNumber = GetFieldValue(invoice.Fields, "InvoiceId") ?? 
                                               GetFieldValue(invoice.Fields, "DocumentId") ??
                                               GetFieldValue(invoice.Fields, "InvoiceNumber") ??
                                               GetFieldValue(invoice.Fields, "BillNumber") ??
                                               GetFieldValue(invoice.Fields, "Number"),
                                billDate = GetFieldValue(invoice.Fields, "InvoiceDate") ?? 
                                          GetFieldValue(invoice.Fields, "DocumentDate") ??
                                          GetFieldValue(invoice.Fields, "BillDate") ??
                                          GetFieldValue(invoice.Fields, "Date") ??
                                          GetFieldValue(invoice.Fields, "IssuedDate"),
                                dueDate = GetFieldValue(invoice.Fields, "DueDate") ??
                                         GetFieldValue(invoice.Fields, "PaymentDate"),
                                // Financial details - try multiple field combinations for accurate mapping
                                grossAmount = ParseDouble(GetFieldValue(invoice.Fields, "SubTotal")) ?? 
                                             ParseDouble(GetFieldValue(invoice.Fields, "AmountDue")) ??
                                             ParseDouble(GetFieldValue(invoice.Fields, "TaxableAmount")) ??
                                             ParseDouble(GetFieldValue(invoice.Fields, "GrossAmount")),
                                gstAmount = ParseDouble(GetFieldValue(invoice.Fields, "TotalTax")) ?? 
                                           ParseDouble(GetFieldValue(invoice.Fields, "Tax")) ??
                                           ParseDouble(GetFieldValue(invoice.Fields, "GST")) ??
                                           ParseDouble(GetFieldValue(invoice.Fields, "TaxAmount")) ??
                                           ParseDouble(GetFieldValue(invoice.Fields, "CGST")) ??
                                           ParseDouble(GetFieldValue(invoice.Fields, "SGST")) ??
                                           ParseDouble(GetFieldValue(invoice.Fields, "IGST")),
                                netAmount = ParseDouble(GetFieldValue(invoice.Fields, "InvoiceTotal")) ?? 
                                           ParseDouble(GetFieldValue(invoice.Fields, "Total")) ??
                                           ParseDouble(GetFieldValue(invoice.Fields, "TotalAmount")) ??
                                           ParseDouble(GetFieldValue(invoice.Fields, "NetAmount")) ??
                                           ParseDouble(GetFieldValue(invoice.Fields, "AmountPayable")),
                                // Quantity details (we'll try to calculate from items)
                                totalCases = CalculateTotalCases(invoice.Fields),
                                totalPieces = CalculateTotalPieces(invoice.Fields),
                                // Items for detailed breakdown
                                items = ExtractItems(invoice.Fields),
                                // Legacy field mappings for backward compatibility
                                vendorName = GetFieldValue(invoice.Fields, "VendorName"),
                                invoiceId = GetFieldValue(invoice.Fields, "InvoiceId"),
                                invoiceDate = GetFieldValue(invoice.Fields, "InvoiceDate"),
                                totalAmount = ParseDouble(GetFieldValue(invoice.Fields, "InvoiceTotal")),
                                subTotal = ParseDouble(GetFieldValue(invoice.Fields, "SubTotal")),
                                taxAmount = ParseDouble(GetFieldValue(invoice.Fields, "TotalTax"))
                            };

                            _logger.LogInformation($"Extracted data: {JsonSerializer.Serialize(extractedData)}");

                            // Update Firestore with extracted data
                            if (_firestoreDb != null)
                            {
                                try
                                {
                                    var invoiceRef = _firestoreDb.Collection("tenants")
                                        .Document(request.TenantId)
                                        .Collection("invoices")
                                        .Document(request.InvoiceId);

                                    var updateData = new Dictionary<string, object>
                                    {
                                        ["status"] = "completed",
                                        ["extractedData"] = extractedData,
                                        ["processedAt"] = DateTime.UtcNow
                                    };

                                    await invoiceRef.UpdateAsync(updateData);
                                    _logger.LogInformation("Invoice updated with extracted data");

                                    // Save inventory items to separate collection
                                    if (extractedData.items != null && extractedData.items.Count > 0)
                                    {
                                        await SaveInventoryItems(request.TenantId, request.InvoiceId, extractedData.items);
                                        _logger.LogInformation($"Saved {extractedData.items.Count} inventory items");
                                    }
                                }
                                catch (Exception ex)
                                {
                                    _logger.LogError(ex, "Failed to update Firestore with extracted data");
                                }
                            }

                            var response = req.CreateResponse(HttpStatusCode.OK);
                            response.Headers.Add("Content-Type", "application/json");
                            await response.WriteStringAsync(JsonSerializer.Serialize(new {
                                success = true,
                                message = "Invoice processed successfully",
                                data = extractedData
                            }));
                            return response;
                        }
                        else
                        {
                            _logger.LogWarning("No documents found in the analysis result");
                            await UpdateInvoiceStatus(request.TenantId, request.InvoiceId, "failed", "No documents found in analysis");
                        }
                    }
                    catch (Exception ex)
                    {
                        _logger.LogError(ex, "Document Intelligence processing failed");
                        await UpdateInvoiceStatus(request.TenantId, request.InvoiceId, "failed", $"Processing error: {ex.Message}");
                        
                        var errorResponse = req.CreateResponse(HttpStatusCode.InternalServerError);
                        errorResponse.Headers.Add("Content-Type", "application/json");
                        await errorResponse.WriteStringAsync(JsonSerializer.Serialize(new {
                            success = false,
                            error = ex.Message
                        }));
                        return errorResponse;
                    }
                }
                else
                {
                    _logger.LogWarning("Document Intelligence client not available");
                    await UpdateInvoiceStatus(request.TenantId, request.InvoiceId, "failed", "Document Intelligence not configured");
                }

                var failResponse = req.CreateResponse(HttpStatusCode.InternalServerError);
                failResponse.Headers.Add("Content-Type", "application/json");
                await failResponse.WriteStringAsync(JsonSerializer.Serialize(new {
                    success = false,
                    error = "Processing failed"
                }));
                return failResponse;
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Unexpected error in ProcessInvoice");
                
                var errorResponse = req.CreateResponse(HttpStatusCode.InternalServerError);
                errorResponse.Headers.Add("Content-Type", "application/json");
                await errorResponse.WriteStringAsync(JsonSerializer.Serialize(new { 
                    success = false, 
                    error = ex.Message 
                }));
                return errorResponse;
            }
        }

        private async Task SaveInventoryItems(string tenantId, string invoiceId, List<object> items)
        {
            if (_firestoreDb == null || items == null || items.Count == 0) return;

            try
            {
                _logger.LogInformation($"Processing {items.Count} inventory items for invoice {invoiceId}");
                
                var inventoryCollection = _firestoreDb.Collection("tenants")
                    .Document(tenantId)
                    .Collection("inventory");

                var now = DateTime.UtcNow;

                foreach (var item in items)
                {
                    var itemData = new Dictionary<string, object>
                    {
                        ["tenantId"] = tenantId,
                        ["updatedAt"] = now
                    };

                    // Add item properties using reflection
                    var itemType = item.GetType();
                    string? itemName = null;
                    string? itemCode = null;
                    double quantity = 0;
                    double? unitPrice = null;
                    double? totalPrice = null;

                    foreach (var prop in itemType.GetProperties())
                    {
                        var value = prop.GetValue(item);
                        if (value != null)
                        {
                            itemData[prop.Name] = value;
                            
                            // Extract key values for duplicate checking
                            if (prop.Name.Equals("description", StringComparison.OrdinalIgnoreCase))
                                itemName = value.ToString();
                            else if (prop.Name.Equals("itemCode", StringComparison.OrdinalIgnoreCase))
                                itemCode = value.ToString();
                            else if (prop.Name.Equals("quantity", StringComparison.OrdinalIgnoreCase))
                                quantity = Convert.ToDouble(value);
                            else if (prop.Name.Equals("unitPrice", StringComparison.OrdinalIgnoreCase))
                                unitPrice = Convert.ToDouble(value);
                            else if (prop.Name.Equals("totalPrice", StringComparison.OrdinalIgnoreCase))
                                totalPrice = Convert.ToDouble(value);
                        }
                    }

                    if (string.IsNullOrEmpty(itemName))
                    {
                        _logger.LogWarning("Skipping item with empty name");
                        continue;
                    }

                    // Check for existing item by name or code
                    Query query = inventoryCollection.WhereEqualTo("itemName", itemName);
                    if (!string.IsNullOrEmpty(itemCode))
                    {
                        query = inventoryCollection.WhereEqualTo("itemCode", itemCode);
                    }

                    var existingItemsSnapshot = await query.GetSnapshotAsync();
                    
                    if (existingItemsSnapshot.Documents.Count > 0)
                    {
                        // Update existing item - aggregate quantities and update prices
                        var existingDoc = existingItemsSnapshot.Documents[0];
                        var existingData = existingDoc.ToDictionary();
                        
                        var currentQuantity = Convert.ToDouble(existingData.GetValueOrDefault("quantity", 0));
                        var currentPieces = Convert.ToInt32(existingData.GetValueOrDefault("piecesCount", 0));
                        var newPieces = Convert.ToInt32(quantity);
                        
                        var updateData = new Dictionary<string, object>
                        {
                            ["quantity"] = currentQuantity + quantity,
                            ["piecesCount"] = currentPieces + newPieces,
                            ["updatedAt"] = now,
                            ["lastInvoiceId"] = invoiceId // Track which invoice last updated this
                        };

                        // Update prices if provided (keep most recent)
                        if (unitPrice.HasValue)
                            updateData["rate"] = unitPrice.Value;
                        if (totalPrice.HasValue)
                            updateData["mrp"] = unitPrice ?? totalPrice.Value; // Use unit price as MRP if available

                        // Add to invoice history for tracking
                        var invoiceHistory = existingData.GetValueOrDefault("invoiceHistory", new List<object>()) as List<object> ?? new List<object>();
                        invoiceHistory.Add(new Dictionary<string, object>
                        {
                            ["invoiceId"] = invoiceId,
                            ["quantity"] = quantity,
                            ["unitPrice"] = unitPrice ?? 0,
                            ["addedAt"] = now
                        });
                        updateData["invoiceHistory"] = invoiceHistory;

                        await existingDoc.Reference.UpdateAsync(updateData);
                        _logger.LogInformation($"Updated existing inventory item: {itemName} (added {quantity} units)");
                    }
                    else
                    {
                        // Create new inventory item
                        var inventoryRef = inventoryCollection.Document(); // Auto-generated ID
                        
                        itemData["id"] = inventoryRef.Id;
                        itemData["itemName"] = itemName;
                        if (!string.IsNullOrEmpty(itemCode))
                            itemData["itemCode"] = itemCode;
                        itemData["piecesCount"] = Convert.ToInt32(quantity);
                        if (unitPrice.HasValue)
                            itemData["rate"] = unitPrice.Value;
                        if (unitPrice.HasValue)
                            itemData["mrp"] = unitPrice.Value;
                        else if (totalPrice.HasValue)
                            itemData["mrp"] = totalPrice.Value;
                        itemData["invoiceId"] = invoiceId; // First invoice that created this item
                        itemData["createdAt"] = now;
                        
                        // Initialize invoice history
                        itemData["invoiceHistory"] = new List<object>
                        {
                            new Dictionary<string, object>
                            {
                                ["invoiceId"] = invoiceId,
                                ["quantity"] = quantity,
                                ["unitPrice"] = unitPrice ?? 0,
                                ["addedAt"] = now
                            }
                        };

                        await inventoryRef.SetAsync(itemData);
                        _logger.LogInformation($"Created new inventory item: {itemName} (quantity: {quantity})");
                    }
                }

                _logger.LogInformation("Successfully processed inventory items to Firestore");
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Failed to save inventory items to Firestore");
            }
        }

        private async Task UpdateInvoiceStatus(string tenantId, string invoiceId, string status, string? errorMessage = null)
        {
            if (_firestoreDb == null) return;

            try
            {
                var invoiceRef = _firestoreDb.Collection("tenants")
                    .Document(tenantId)
                    .Collection("invoices")
                    .Document(invoiceId);

                var updateData = new Dictionary<string, object>
                {
                    ["status"] = status,
                    ["processedAt"] = DateTime.UtcNow
                };

                if (!string.IsNullOrEmpty(errorMessage))
                {
                    updateData["errorMessage"] = errorMessage;
                }

                // Use SetAsync with merge to create document if it doesn't exist
                await invoiceRef.SetAsync(updateData, SetOptions.MergeAll);
                _logger.LogInformation($"Updated invoice {invoiceId} status to {status}");
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, $"Failed to update invoice status to {status}");
            }
        }

        private static string? GetFieldValue(IReadOnlyDictionary<string, DocumentField> fields, string fieldName)
        {
            if (fields.TryGetValue(fieldName, out var field) && field.Value != null)
            {
                return field.FieldType switch
                {
                    DocumentFieldType.String => field.Value.AsString(),
                    DocumentFieldType.Currency => field.Value.AsCurrency().Amount.ToString("F2"),
                    DocumentFieldType.Date => field.Value.AsDate().ToString("yyyy-MM-dd"),
                    DocumentFieldType.Double => field.Value.AsDouble().ToString("F2"),
                    DocumentFieldType.Int64 => field.Value.AsInt64().ToString(),
                    _ => field.Value.ToString()
                };
            }
            return null;
        }

        private static List<object> ExtractItems(IReadOnlyDictionary<string, DocumentField> fields)
        {
            var items = new List<object>();
            
            if (fields.TryGetValue("Items", out var itemsField) && itemsField.FieldType == DocumentFieldType.List)
            {
                foreach (var item in itemsField.Value.AsList())
                {
                    if (item.FieldType == DocumentFieldType.Dictionary)
                    {
                        var itemDict = item.Value.AsDictionary();
                        var description = GetFieldValue(itemDict, "Description") ?? "";
                        var quantity = ParseDouble(GetFieldValue(itemDict, "Quantity")) ?? 1;
                        var unitPrice = ParseDouble(GetFieldValue(itemDict, "UnitPrice")) ?? 0;
                        var totalPrice = ParseDouble(GetFieldValue(itemDict, "Amount")) ?? 0;
                        
                        // Enhanced item extraction for inventory tracking
                        items.Add(new
                        {
                            description = description,
                            quantity = quantity,
                            unitPrice = unitPrice,
                            totalPrice = totalPrice,
                            // Additional fields for inventory
                            itemName = ExtractItemName(description),
                            itemCode = ExtractItemCode(description),
                            piecesCount = ExtractPiecesCount(description, quantity),
                            unit = ExtractUnit(description),
                            mrp = ExtractMRP(description, unitPrice),
                            rate = unitPrice,
                            discountAmount = CalculateDiscount(description, unitPrice, totalPrice),
                        });
                    }
                }
            }
            
            return items;
        }

        private static double? ParseDouble(string? value)
        {
            if (string.IsNullOrEmpty(value))
                return null;
                
            if (double.TryParse(value, out var result))
                return result;
                
            return null;
        }

        private static int? CalculateTotalCases(IReadOnlyDictionary<string, DocumentField> fields)
        {
            int totalCases = 0;
            bool foundCases = false;

            // Try to extract from line items
            if (fields.TryGetValue("Items", out var itemsField) && itemsField.FieldType == DocumentFieldType.List)
            {
                foreach (var item in itemsField.Value.AsList())
                {
                    if (item.FieldType == DocumentFieldType.Dictionary)
                    {
                        var itemDict = item.Value.AsDictionary();
                        
                        // Look for quantity in each item and try to parse cases from description
                        var description = GetFieldValue(itemDict, "Description")?.ToLower() ?? "";
                        var quantity = GetFieldValue(itemDict, "Quantity");
                        
                        // Try to extract case count from description (e.g., "(48 Nos)", "(12Nos)")
                        var match = System.Text.RegularExpressions.Regex.Match(description, @"\((\d+)\s*nos?\)");
                        if (match.Success && int.TryParse(match.Groups[1].Value, out var caseCount))
                        {
                            totalCases += caseCount;
                            foundCases = true;
                        }
                        else if (!string.IsNullOrEmpty(quantity) && int.TryParse(quantity, out var qty))
                        {
                            totalCases += qty;
                            foundCases = true;
                        }
                    }
                }
            }

            return foundCases ? totalCases : null;
        }

        private static int? CalculateTotalPieces(IReadOnlyDictionary<string, DocumentField> fields)
        {
            int totalPieces = 0;
            bool foundPieces = false;

            // Try to extract from line items
            if (fields.TryGetValue("Items", out var itemsField) && itemsField.FieldType == DocumentFieldType.List)
            {
                foreach (var item in itemsField.Value.AsList())
                {
                    if (item.FieldType == DocumentFieldType.Dictionary)
                    {
                        var itemDict = item.Value.AsDictionary();
                        
                        // Look for quantity in each item 
                        var description = GetFieldValue(itemDict, "Description")?.ToLower() ?? "";
                        var quantity = GetFieldValue(itemDict, "Quantity");
                        
                        // Try to extract piece count from description patterns
                        // Look for patterns like "48 ML (48 Nos)" where the number in parentheses is pieces
                        var match = System.Text.RegularExpressions.Regex.Match(description, @"\((\d+)\s*nos?\)");
                        if (match.Success && int.TryParse(match.Groups[1].Value, out var pieceCount))
                        {
                            totalPieces += pieceCount;
                            foundPieces = true;
                        }
                        else if (!string.IsNullOrEmpty(quantity) && int.TryParse(quantity, out var qty))
                        {
                            totalPieces += qty;
                            foundPieces = true;
                        }
                    }
                }
            }

            return foundPieces ? totalPieces : null;
        }

        private static string? GetSupplierFromDescription(IReadOnlyDictionary<string, DocumentField> fields)
        {
            // First try vendor address or vendor name fields
            var vendorName = GetFieldValue(fields, "VendorName");
            if (!string.IsNullOrEmpty(vendorName))
            {
                var lowerVendor = vendorName.ToLower();
                if (lowerVendor.Contains("aravindhan") || lowerVendor.Contains("agency"))
                {
                    return "Aravindhan Agency";
                }
                // If VendorName contains "snowy" or "milk", then this is actually the customer, not supplier
                if (lowerVendor.Contains("snowy") || lowerVendor.Contains("milk"))
                {
                    return null; // Don't use this as supplier
                }
                return vendorName; // Use the vendor name as is
            }
            
            // Try to find supplier name in items descriptions or other fields
            if (fields.TryGetValue("Items", out var itemsField) && itemsField.FieldType == DocumentFieldType.List)
            {
                foreach (var item in itemsField.Value.AsList())
                {
                    if (item.FieldType == DocumentFieldType.Dictionary)
                    {
                        var itemDict = item.Value.AsDictionary();
                        var description = GetFieldValue(itemDict, "Description")?.ToLower() ?? "";
                        
                        // Look for common supplier patterns in descriptions
                        if (description.Contains("aravindhan") || description.Contains("agency"))
                        {
                            return "Aravindhan Agency";
                        }
                    }
                }
            }
            
            // Check vendor address fields for supplier information
            var vendorAddress = GetFieldValue(fields, "VendorAddress");
            if (!string.IsNullOrEmpty(vendorAddress))
            {
                var lowerAddress = vendorAddress.ToLower();
                if (lowerAddress.Contains("aravindhan") || lowerAddress.Contains("agency"))
                {
                    return "Aravindhan Agency";
                }
            }
            
            return null;
        }

        private static string? GetCustomerFromFields(IReadOnlyDictionary<string, DocumentField> fields)
        {
            // Try multiple customer-related fields
            var customerName = GetFieldValue(fields, "CustomerName") ?? 
                              GetFieldValue(fields, "BillingAddressRecipient") ?? 
                              GetFieldValue(fields, "ShippingAddressRecipient");
                              
            if (!string.IsNullOrEmpty(customerName))
            {
                var lower = customerName.ToLower();
                if (lower.Contains("snowy") || lower.Contains("milk") || lower.Contains("parlour"))
                {
                    return "Snowy Milk Parlour";
                }
                return customerName;
            }
            
            // Check if VendorName actually contains customer info (some invoices have this reversed)
            var vendorName = GetFieldValue(fields, "VendorName");
            if (!string.IsNullOrEmpty(vendorName))
            {
                var lower = vendorName.ToLower();
                if (lower.Contains("snowy") || lower.Contains("milk") || lower.Contains("parlour"))
                {
                    return "Snowy Milk Parlour";
                }
            }
            
            return null;
        }

        private static string ExtractItemName(string description)
        {
            if (string.IsNullOrEmpty(description)) return "Unknown Item";
            
            // Remove common patterns and clean up the name
            var itemName = description.Trim();
            
            // Remove quantity patterns like "(48 Nos)", "[12 PCS]", etc.
            itemName = System.Text.RegularExpressions.Regex.Replace(itemName, @"\([0-9]+\s*(nos?|pcs?|pieces?|ml|gm|kg)\)", "", System.Text.RegularExpressions.RegexOptions.IgnoreCase);
            itemName = System.Text.RegularExpressions.Regex.Replace(itemName, @"\[[0-9]+\s*(nos?|pcs?|pieces?|ml|gm|kg)\]", "", System.Text.RegularExpressions.RegexOptions.IgnoreCase);
            
            // Remove extra spaces
            itemName = System.Text.RegularExpressions.Regex.Replace(itemName, @"\s+", " ").Trim();
            
            return itemName;
        }

        private static string? ExtractItemCode(string description)
        {
            if (string.IsNullOrEmpty(description)) return null;
            
            // Look for alphanumeric codes (e.g., "AMUL001", "ICE123", "CREAM456")
            var match = System.Text.RegularExpressions.Regex.Match(description.ToUpper(), @"\b[A-Z]{2,}[0-9]{1,}\b");
            if (match.Success)
            {
                return match.Value;
            }
            
            // Look for numeric codes at the beginning or end
            match = System.Text.RegularExpressions.Regex.Match(description, @"\b[0-9]{3,}\b");
            if (match.Success)
            {
                return match.Value;
            }
            
            return null;
        }

        private static int ExtractPiecesCount(string description, double quantity)
        {
            if (string.IsNullOrEmpty(description)) 
                return (int)Math.Max(1, quantity);
            
            // Look for patterns like "(48 Nos)", "(12 PCS)", "[24 Pieces]"
            var match = System.Text.RegularExpressions.Regex.Match(description, @"[\(\[](\d+)\s*(?:nos?|pcs?|pieces?)[\)\]]", System.Text.RegularExpressions.RegexOptions.IgnoreCase);
            if (match.Success && int.TryParse(match.Groups[1].Value, out var pieces))
            {
                return pieces;
            }
            
            // If no specific pieces found, use quantity as pieces count
            return (int)Math.Max(1, quantity);
        }

        private static string ExtractUnit(string description)
        {
            if (string.IsNullOrEmpty(description)) return "PCS";
            
            var upperDesc = description.ToUpper();
            
            // Common units in ice cream/dairy business
            if (upperDesc.Contains("ML")) return "ML";
            if (upperDesc.Contains("LTR") || upperDesc.Contains("LITER")) return "LTR";
            if (upperDesc.Contains("KG") || upperDesc.Contains("KILOGRAM")) return "KG";
            if (upperDesc.Contains("GM") || upperDesc.Contains("GRAM")) return "GM";
            if (upperDesc.Contains("PCS") || upperDesc.Contains("PIECE")) return "PCS";
            if (upperDesc.Contains("BOX") || upperDesc.Contains("CARTON")) return "BOX";
            
            return "PCS"; // Default unit
        }

        private static double? ExtractMRP(string description, double unitPrice)
        {
            if (string.IsNullOrEmpty(description)) return null;
            
            // Look for MRP patterns like "MRP: 25", "MRP 25", "₹25 MRP"
            var mrpMatch = System.Text.RegularExpressions.Regex.Match(description, @"(?:mrp|M\.R\.P\.?)\s*:?\s*₹?(\d+(?:\.\d{2})?)", System.Text.RegularExpressions.RegexOptions.IgnoreCase);
            if (mrpMatch.Success && double.TryParse(mrpMatch.Groups[1].Value, out var mrp))
            {
                return mrp;
            }
            
            // If no MRP found, estimate it as 15-25% higher than unit price (common margin)
            if (unitPrice > 0)
            {
                return Math.Round(unitPrice * 1.2, 2); // 20% markup as estimate
            }
            
            return null;
        }

        private static double? CalculateDiscount(string description, double unitPrice, double totalPrice)
        {
            if (unitPrice <= 0 || totalPrice <= 0) return null;
            
            // Look for discount patterns in description
            var discountMatch = System.Text.RegularExpressions.Regex.Match(description, @"(?:discount|disc\.?)\s*:?\s*₹?(\d+(?:\.\d{2})?)", System.Text.RegularExpressions.RegexOptions.IgnoreCase);
            if (discountMatch.Success && double.TryParse(discountMatch.Groups[1].Value, out var discount))
            {
                return discount;
            }
            
            // Calculate discount if total is less than expected (unit price * quantity would be higher)
            // This is a rough estimation
            var expectedTotal = unitPrice;
            if (expectedTotal > totalPrice)
            {
                return Math.Round(expectedTotal - totalPrice, 2);
            }
            
            return null;
        }

    }

    public class InvoiceProcessRequest
    {
        [JsonPropertyName("tenantId")]
        public string TenantId { get; set; } = string.Empty;
        
        [JsonPropertyName("invoiceId")]
        public string InvoiceId { get; set; } = string.Empty;
        
        [JsonPropertyName("imageUrl")]
        public string ImageUrl { get; set; } = string.Empty;
    }
}

$port = 3000
$root = "C:\Users\Jagannath\.gemini\antigravity\scratch\vuo-csc-help"
$listener = New-Object System.Net.HttpListener
$listener.Prefixes.Add("http://localhost:$port/")
$listener.Start()
Write-Output "VUO CSC HELP HTTP Server started at http://localhost:$port/"

while ($listener.IsListening) {
    try {
        $context = $listener.GetContext()
        $request = $context.Request
        $response = $context.Response
        
        $urlPath = [System.Uri]::UnescapeDataString($request.Url.LocalPath).TrimStart('/')
        if ([string]::IsNullOrWhiteSpace($urlPath) -or $urlPath -eq '/') {
            $urlPath = "index.html"
        }

        # Handle API Upload for CSC PDF Forms
        if ($request.HttpMethod -eq 'POST' -and $urlPath -eq 'api/upload-form') {
            try {
                $enc = if ($request.ContentEncoding) { $request.ContentEncoding } else { [System.Text.Encoding]::UTF8 }
                $reader = New-Object System.IO.StreamReader($request.InputStream, $enc)
                $body = $reader.ReadToEnd()
                $json = $body | ConvertFrom-Json
                if ($json.fileName -and $json.base64Data) {
                    $rawBase64 = $json.base64Data -replace '^data:[^;]+;base64,', ''
                    $fileBytes = [System.Convert]::FromBase64String($rawBase64)
                    $cleanName = [System.IO.Path]::GetFileName($json.fileName)
                    $destPath = Join-Path (Join-Path $root "forms") $cleanName
                    [System.IO.File]::WriteAllBytes($destPath, $fileBytes)

                    $respJson = @{
                        success = $true
                        fileName = $cleanName
                        fileUrl = "forms/$cleanName"
                        size = "$([math]::Round($fileBytes.Length / 1KB)) KB"
                    } | ConvertTo-Json

                    $bytes = [System.Text.Encoding]::UTF8.GetBytes($respJson)
                    $response.ContentType = "application/json; charset=utf-8"
                    $response.StatusCode = 200
                    $response.OutputStream.Write($bytes, 0, $bytes.Length)
                } else {
                    $response.StatusCode = 400
                    $bytes = [System.Text.Encoding]::UTF8.GetBytes('{"success":false,"error":"Missing fileName or base64Data"}')
                    $response.OutputStream.Write($bytes, 0, $bytes.Length)
                }
            } catch {
                $response.StatusCode = 500
                $errMsg = $_.Exception.Message
                $bytes = [System.Text.Encoding]::UTF8.GetBytes("{`"success`":false,`"error`":`"$errMsg`"}")
                $response.OutputStream.Write($bytes, 0, $bytes.Length)
            }
            $response.Close()
            continue
        }
        
        $filePath = Join-Path $root $urlPath
        if (Test-Path $filePath -PathType Leaf) {
            $ext = [System.IO.Path]::GetExtension($filePath).ToLower()
            $contentType = switch ($ext) {
                ".html" { "text/html; charset=utf-8" }
                ".htm"  { "text/html; charset=utf-8" }
                ".css"  { "text/css; charset=utf-8" }
                ".js"   { "application/javascript; charset=utf-8" }
                ".json" { "application/json; charset=utf-8" }
                ".svg"  { "image/svg+xml" }
                ".png"  { "image/png" }
                ".jpg"  { "image/jpeg" }
                ".jpeg" { "image/jpeg" }
                ".gif"  { "image/gif" }
                ".ico"  { "image/x-icon" }
                ".pdf"  { "application/pdf" }
                ".docx" { "application/vnd.openxmlformats-officedocument.wordprocessingml.document" }
                default { "application/octet-stream" }
            }
            
            $bytes = [System.IO.File]::ReadAllBytes($filePath)
            $response.ContentType = $contentType
            $response.ContentLength64 = $bytes.Length
            $response.StatusCode = 200
            $response.OutputStream.Write($bytes, 0, $bytes.Length)
        } else {
            $response.StatusCode = 404
            $msg = [System.Text.Encoding]::UTF8.GetBytes("404 Not Found")
            $response.OutputStream.Write($msg, 0, $msg.Length)
        }
        $response.Close()
    } catch {
        # continue loop
    }
}

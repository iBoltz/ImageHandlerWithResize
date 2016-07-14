<%@ WebHandler Language="VB" Class="PhotoHandler" %>
Imports System
Imports System.Web
Imports System.Data.SqlClient
Imports System.Data
Imports System.IO
Imports System.Drawing.Imaging
Imports System.Drawing
Imports System.Drawing.Drawing2D
Imports System.Diagnostics
Imports iBoltz.ImageResize
Imports iBoltz.ImageResize.Web

Public Class PhotoHandler : Implements IHttpHandler, IReadOnlySessionState
    Private ImageWidth As Integer?
    Private ImageHeight As Integer?
    Private IsThubmNail As Boolean
    Private ScaleRatio As Double?
    Public Sub ProcessRequest(ByVal Context As HttpContext) Implements IHttpHandler.ProcessRequest
        Try

            Context.Response.Clear()
            Context.Response.ContentType = "image/png"

            Dim c As HttpCachePolicy = Context.Response.Cache
            c.SetCacheability(HttpCacheability.Public)
            c.SetMaxAge(New TimeSpan(10, 0, 0, 0))

            Dim PhotoID = Context.Request.Params("Id")
            Dim FromPath = Context.Request.Params("FromPath")
            If (Context.Request.Params("IsThumb") Is Nothing OrElse String.IsNullOrEmpty(Context.Request.Params("IsThumb"))) Then
                IsThubmNail = False
            Else
                IsThubmNail = Context.Request.Params("IsThumb")
            End If

            ImageWidth = RequestHelper.GetIntParam("Width")
            ImageHeight = RequestHelper.GetIntParam("Height")

            Dim PhotoPath As String = GetPhotoPathFromTextFile(Context)

            If String.IsNullOrEmpty(PhotoPath) Then Return

            If (Not File.Exists(Context.Server.MapPath(PhotoPath))) Then
                PhotoPath = "~/Images/NoPhotos.png"
            End If

            VerifyModification(Context)
            ProcessImageResize(Context, PhotoPath)
        Catch ex As Exception
            LogHelper.HandleException(ex)
        End Try

    End Sub
    Public Sub ProcessImageResize(ByVal Context As HttpContext, PhotoPath As String)
        Try
            Dim fullSizeImg = System.Drawing.Image.FromFile(Context.Server.MapPath(PhotoPath))
            Dim ActualWidth = fullSizeImg.Width
            Dim ActualHeight = fullSizeImg.Height

            If (ImageWidth Is Nothing Or ImageHeight Is Nothing) Then
                If (IsThubmNail) Then
                    ImageWidth = 240
                    ImageHeight = 200
                Else
                    ImageWidth = ActualWidth
                    ImageHeight = ActualHeight
                End If
            End If

            Dim HorizontalResizeRatio = (ImageWidth / ActualWidth)
            Dim VerticalResizeRatio = (ImageHeight / ActualHeight)

            If (VerticalResizeRatio = HorizontalResizeRatio) Then
                'no croping necessary
                ScaleRatio = VerticalResizeRatio
            Else

                If (HorizontalResizeRatio > VerticalResizeRatio) Then 'width is longer than height
                    ScaleRatio = HorizontalResizeRatio
                    'crop vertically, leave horizontal as it is
                    Dim NewHeight = ((ActualHeight * VerticalResizeRatio) / HorizontalResizeRatio)
                    Dim vOffset = (ActualHeight - NewHeight) / 2
                    fullSizeImg = ImageHelper.CropImage(fullSizeImg, New Point(0, vOffset), New Point(ActualWidth, vOffset + NewHeight))
                Else
                    ScaleRatio = VerticalResizeRatio
                    'crop vertically, leave horizontal as it is
                    Dim NewWidth = ((ActualWidth * HorizontalResizeRatio) / VerticalResizeRatio)
                    Dim hOffset = (ActualWidth - NewWidth) / 2
                    fullSizeImg = ImageHelper.CropImage(fullSizeImg, New Point(hOffset, 0), New Point(hOffset + NewWidth, ActualHeight))
                End If
            End If

            If (IsThubmNail = "1") Then
                RenderThumb(fullSizeImg, Context, PhotoPath)
            Else
                Dim Resized = fullSizeImg
                If (ScaleRatio IsNot Nothing) Then
                    Resized = ImageHelper.ResizeImage(ScaleRatio, fullSizeImg)
                End If
                SaveCached(Resized, PhotoPath)
                RenderFull(Resized, Context)
            End If

        Catch ex As Exception
            LogHelper.HandleException(ex)
        End Try
    End Sub

    Public Sub VerifyModification(ByVal Context As HttpContext)
        Try
            Dim rawIfModifiedSince As String = Context.Request.Headers.Get("If-Modified-Since")
            Dim PhotoLastModified As DateTime = Now
            If (String.IsNullOrEmpty(rawIfModifiedSince)) Then
                Context.Response.Cache.SetLastModified(PhotoLastModified)
            Else
                Dim ifModifiedSince As DateTime = DateTime.Parse(rawIfModifiedSince)
                If (PhotoLastModified.AddMilliseconds(-PhotoLastModified.Millisecond) = ifModifiedSince) Then
                    Context.Response.ClearContent()
                    Context.Response.StatusCode = 304
                    Context.Response.StatusDescription = "Not Modified"
                    Context.Response.SuppressContent = True
                    Return
                End If
            End If

        Catch ex As Exception
            LogHelper.HandleException(ex)
        End Try
    End Sub

    Public Sub SaveCached(SrcImage As Image, PhotoPath As String)
        Try

            Dim ThisFolder = String.Empty
            Dim ThisFileName = String.Empty
            Dim LocalPath = HttpContext.Current.Server.MapPath(PhotoPath)

            If (LocalPath.LastIndexOf("\"c) > 0) Then
                ThisFileName = LocalPath.Substring(LocalPath.LastIndexOf("\"c) + 1, LocalPath.Length - LocalPath.LastIndexOf("\"c) - 1)
                If ThisFileName Is Nothing Then Return
                ThisFolder = LocalPath.Remove(LocalPath.LastIndexOf("\"c), LocalPath.Length - LocalPath.LastIndexOf("\"c))
                If ThisFolder Is Nothing Then Return
                SrcImage.Save(ThisFolder & "\" & ImageWidth & "_" & ImageHeight & "_" & ThisFileName)
            End If
        Catch ex As Exception
            LogHelper.HandleException(ex)
        End Try
    End Sub

    Public Sub RenderFull(ByVal FinalImage As Image, ByVal Context As HttpContext)
        Try
            If (FinalImage IsNot Nothing) Then
                Dim PhotoData = GetBmpBytes(FinalImage)

                Context.Response.OutputStream.Write(PhotoData, 0, PhotoData.Length)
                Context.Response.End()
            End If
        Catch ex As Exception
            LogHelper.HandleException(ex)
        End Try
    End Sub
    Private Sub RenderThumb(ByVal fullSizeImg As Image, ByVal Context As HttpContext,
                            ByVal PhotoPath As String)
        Try
            'Create the delegate
            Dim dummyCallBack = New System.Drawing.Image.GetThumbnailImageAbort(AddressOf ThumbnailCallback)


            Dim thumbNailImg As System.Drawing.Image
            thumbNailImg = fullSizeImg.GetThumbnailImage(ImageWidth, ImageHeight, dummyCallBack, IntPtr.Zero)

            SaveCached(thumbNailImg, PhotoPath)
            Dim bmpBytes = GetBmpBytes(thumbNailImg)
            Context.Response.OutputStream.Write(bmpBytes, 0, bmpBytes.Length)

        Catch ex As Exception
            LogHelper.HandleException(ex)
        End Try
    End Sub
    Private Shared Function GetBmpBytes(ByVal thumbNailImg As System.Drawing.Image) As Byte()
        Try
            Dim ms = New MemoryStream()
            thumbNailImg.Save(ms, ImageFormat.Jpeg)
            Dim bmpBytes = ms.GetBuffer()
            thumbNailImg.Dispose()
            ms.Close()
            Return bmpBytes
        Catch ex As Exception
            LogHelper.HandleException(ex)
            Return Nothing
        End Try
    End Function
    Function ThumbnailCallback() As Boolean
        Return False
    End Function


    Public ReadOnly Property IsReusable() As Boolean Implements IHttpHandler.IsReusable
        Get
            Return False
        End Get
    End Property
    Private Function GetPhotoPathFromTextFile(ByVal Context As HttpContext) As String
        Try
            ''Get from textfile
            Dim path As String = AppDomain.CurrentDomain.BaseDirectory + "input.txt"
            Dim PhotoID = Context.Request.Params("Id")
            If PhotoID Is Nothing Then Return Nothing

            Dim InputText = My.Computer.FileSystem.ReadAllText(path)
            If InputText Is Nothing Then Return Nothing
            Dim SplitedText = InputText.Split("|")

            If SplitedText.Count = 0 Then Return Nothing
            If CInt(SplitedText(0)) = CInt(PhotoID) Then
                Return SplitedText(1)
            End If

        Catch ex As Exception
            LogHelper.HandleException(ex)

        End Try
        Return Nothing
    End Function


End Class

Imports Microsoft.Practices.EnterpriseLibrary.Logging
Imports Microsoft.Practices.EnterpriseLibrary.ExceptionHandling
Imports Microsoft.Practices.EnterpriseLibrary.Common.Configuration
Imports Microsoft.Practices.EnterpriseLibrary.Data

Public Class LogHelper
    Private Const ApplicationExceptionPolicy As String = "iBoltzPolicy"

    Public Shared Sub Config()
        DatabaseFactory.SetDatabaseProviderFactory(New DatabaseProviderFactory())

        Dim configurationSource = ConfigurationSourceFactory.Create()
        Dim logWriterFactory = New LogWriterFactory(configurationSource)
        Logger.SetLogWriter(logWriterFactory.Create())

        Dim ExceptionFactory = New ExceptionPolicyFactory(ConfigurationSourceFactory.Create())
        Dim exManager = ExceptionFactory.CreateManager()
        ExceptionPolicy.SetExceptionManager(exManager)
    End Sub


    Public Shared Sub Trace(ByVal Category As String, ByVal Message As String)
        Try

            If Logger.IsLoggingEnabled() Then

                Dim TraceLogEntry As New LogEntry
                With TraceLogEntry
                    .Title = "Title"
                    .Categories.Add(Category)
                    .Message = Message
                    .TimeStamp = Now
                    .Priority = 5
                    .Severity = TraceEventType.Information
                End With
                Logger.Write(TraceLogEntry)
            End If

        Catch ex As System.Threading.SynchronizationLockException
            Debug.WriteLine(ex.Message)
            'do nothing
        Catch ex As Exception
            Debug.WriteLine(ex.Message)
        End Try
    End Sub


    Public Shared Sub HandleException(ByVal Ex As Exception)
        HandleException(Ex, ApplicationExceptionPolicy)
    End Sub
    Public Shared Sub HandleException(ByVal Ex As Exception, Policy As String)
        Try
            ExceptionPolicy.HandleException(Ex, Policy)
        Catch ex1 As Exception
            Debug.Print(ex1.Message)
        End Try

    End Sub
End Class

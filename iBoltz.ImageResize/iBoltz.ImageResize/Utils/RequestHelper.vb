Imports System.Web
Namespace Web
    Public Class RequestHelper
        Public Shared Function GetIntParam(ByVal ParamName As String) As Integer?
            If String.IsNullOrEmpty(GetStringParam(ParamName)) Then
                Return Nothing
            Else
                Return Integer.Parse(GetStringParam(ParamName))
            End If


        End Function
        Public Shared Function GetStringParam(ByVal ParamName As String) As String
            Return HttpContext.Current.Request.QueryString(ParamName)
        End Function


    End Class
End Namespace
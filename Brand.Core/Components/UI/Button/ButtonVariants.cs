namespace Brand.Core.Components.UI.Button;

public static class ButtonVariants
{
    public const string Base =
        "inline-flex items-center justify-center rounded-md font-semibold transition focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-offset-2";

    public static string Variant(string variant) =>
        variant switch
        {
            "secondary" => "bg-white text-gray-900 border border-gray-200 hover:bg-gray-50 focus-visible:ring-gray-900",
            "outline" => "border-2 border-current bg-transparent hover:bg-current/10 focus-visible:ring-current",
            "ghost" => "text-current hover:bg-current/10 focus-visible:ring-current",
            _ => "bg-gray-900 text-white hover:bg-gray-800 focus-visible:ring-gray-900",
        };

    public static string Size(string size) =>
        size switch
        {
            "sm" => "px-3 py-1.5 text-xs",
            "lg" => "px-5 py-3 text-base",
            _ => "px-4 py-2 text-sm",
        };
}

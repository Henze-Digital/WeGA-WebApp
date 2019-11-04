$(function () {
    var url = $('.swagger-section').attr('data-api-base') + "/swagger.json";
    
    // Hide some elements
    const HideInfoUrlPartsPlugin = () => {
        return {
            wrapComponents: {
                InfoUrl: () => () => null,
                InfoBasePath: () => () => null // this hides the `Base Url` part too, if you want that
            }
        }
    }
    
    // Begin Swagger UI call region
    const ui = SwaggerUIBundle({
        url: url,
        dom_id: '#swagger-ui-container',
        deepLinking: true,
        presets:[
        SwaggerUIBundle.presets.apis,
        SwaggerUIStandalonePreset],
        plugins:[
        SwaggerUIBundle.plugins.DownloadUrl,
        HideInfoUrlPartsPlugin],
        layout: "BaseLayout"
    })
    // End Swagger UI call region
    window.ui = ui
});
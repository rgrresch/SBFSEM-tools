function rgbTriplet = selectcolor(varargin)
    % SELECTCOLOR Open a modal dialog box to create a color specification
    %
    %   Syntax
    %   ------
    %   c = selectcolor
    %   c = selectcolor([r g b])
    %   c = selectcolor(..., 'dialogTitle')
    %   c = selectcolor(..., hCaller) 
    %   c = selectcolor(..., 'k') 
    %
    %   Description
    %   -----------
    %   c = selectcolor creates a modal color selection dialog and returns
    %   the selected color. The dialog box output is initialized to white.
    %
    %   c = selectcolor([r g b]) displays a dialog box with the color
    %   specified by [r g b] as the initial selection. The values of r, g,
    %   and b must be values in the range [0, 1].
    %
    %   c = selectcolor(..., 'dialogTitle') creates the dialog box with the
    %   specified title.
    %
    %   c = selectcolor(..., hCaller) displays a dialog box centered over
    %   the figure idendified by the handle hCaller. This is useful for
    %   when you want to call selectcolor from another GUI and have
    %   selectcolor appear in an obvious location.
    %
    %   c = selectcolor(..., 'k') overrides the default system color scheme
    %   and displays a dialog box with a black figure background. The
    %   default color scheme can also be overridden to use a white
    %   background for the dialog figure. Acceptable override strings are
    %   'black', 'k', 'white' or 'w'.
    %
    %   Note that the color channel sliders and edit boxes display choices
    %   in the range [0, 255], but will ouput colors as a valid MATLAB RGB
    %   triplet with values in the range [0, 1];
    %
    %   Like uisetcolor, if the user presses cancel or closes the dialog
    %   box, the output value is set to the input RGB triplet, if provided,
    %   or it is set to 0.
    %
    %   2014, P. Beemiller. Licensed under a Creative Commmons Attribution
    %   license. Please see: http://creativecommons.org/licenses/by/3.0/
    
    %% Parse the inputs.
    selectcolorParser = inputParser;
    selectcolorParser.CaseSensitive = false;
    
    addOptional(selectcolorParser, ...
        'initialColor', [1 1 1], ...
        @(arg)isnumeric(arg) && numel(arg) == 3 && all(arg >= 0) && all(arg <= 1))
    addOptional(selectcolorParser, ...
        'dialogTitle', 'Color', ...
        @(arg)ischar(arg))
    addOptional(selectcolorParser, ...
        'hCaller', -1, ...
        @(arg)ishandle(arg) && strcmp(get(arg, 'Type'), 'figure'))
    addOptional(selectcolorParser, ...
        'OverrideColor', get(0, 'defaultFigureColor'), ...
        @(arg)any(strcmp(arg, {'k', 'w', 'black', 'white'})))
    
    parse(selectcolorParser, varargin{:})
        
    %% Set the dialog colors.
    if any(strcmpi(selectcolorParser.UsingDefaults, 'OverrideColor'))
        guiColor = get(0, 'defaultFigureColor');
        bColor = get(0,'defaultUicontrolBackgroundColor');
        bColorJava = java.awt.Color(guiColor(1), guiColor(2), guiColor(3));
        fColor = get(0,'defaultUicontrolForegroundColor');
        fColorJava = java.awt.Color(fColor(1), fColor(2), fColor(3));
        
    else
        switch selectcolorParser.Results.OverrideColor

            case {'black', 'k'}
                guiColor = [0 0 0];
                bColor = [0.2 0.2 0.2];
                bColorJava = java.awt.Color.black;
                fColor = [1 1 1];
                fColorJava = java.awt.Color.white;

            case {'white', 'w'}
                guiColor = [1 1 1];
                bColor = [0.8 0.8 0.8];
                bColorJava = java.awt.Color.white;
                fColor = [0 0 0];
                fColorJava = java.awt.Color.black;

       end % switch   
    end % if
    
    %% Create the figure.
    guiWidth = 190;
    guiHeight = 220;
    
    if selectcolorParser.Results.hCaller == -1
        parentPos = get(0, 'MonitorPositions');
        guiPos = [...
            (parentPos(1, 1) + parentPos(1, 3) - guiWidth)/2, ...
            (parentPos(1, 2) + parentPos(1, 4) - guiHeight)/2, ...
            guiWidth, ...
            guiHeight];

    else
        parentPos = get(selectcolorParser.Results.hCaller, 'Position');
        guiPos = [...
            parentPos(1) + (parentPos(3) - guiWidth)/2, ...
            parentPos(2) + (parentPos(4) - guiHeight)/2, ...
            guiWidth, ...
            guiHeight];
        
    end % if
    
    guiSelectColor = figure(...
        'CloseRequestFcn', {@pushcancel}, ...
        'Color', guiColor, ...
        'KeyPressFcn', {@guiselectcolorkeypresscallback}, ...
        'MenuBar', 'None', ...
        'Name', selectcolorParser.Results.dialogTitle, ...
        'NumberTitle', 'Off', ...
        'Position', guiPos, ...
        'Resize', 'Off', ...
        'Tag', 'guiSelectColor', ...
        'WindowStyle', 'modal');
    
    %% Create the selected color preview box.
    % Create this axes first, so that we have its handle available to pass
    % to the callbacks.
    if isempty(selectcolorParser.Results.initialColor)
        initialColor = [255 255 255];
        
    else
        initialColor = round(255*selectcolorParser.Results.initialColor);
    
    end % if
    
    axesPreview = axes(...
        'Box', 'On', ...
        'Color', initialColor/255, ...
        'Parent', guiSelectColor, ...
        'Units', 'Pixels', ...
        'Position', [130 160 50 50], ...
        'Tag', 'axesPreview', ...
        'XColor', [89 89 89]/255, ...
        'XTick', [], ...
        'YColor', [89 89 89]/255, ...
        'YTick', []);

    %% Create the hex edit box.
    editHex = uicontrol(...
        'Background', bColor, ...
        'Callback', {@edithexcallback, axesPreview, guiSelectColor}, ...
        'Foreground', fColor, ...
        'Parent', guiSelectColor, ...
        'Position', [130 130 50 20], ...
        'String', [dec2hex(initialColor(1), 2) dec2hex(initialColor(2), 2) dec2hex(initialColor(3), 2)], ...
        'Style', 'edit', ...
        'Tag', 'editHex', ...
        'TooltipString', 'Manually input the color as a hex value');
    
    %% Create the color selection boxes.
    createquickcolors(editHex, axesPreview, guiSelectColor)
    
    %% Create the channel adjustment sliders and direct edit boxes.
    sliderRed = uicomponent(...
        'Background', bColorJava, ...
        'Foreground', fColorJava, ...
        'Minimum', 0, ...
        'Maximum', 255, ...
        'Name', 'sliderRed', ...
        'Parent', guiSelectColor, ...
        'Position', [10 100 110 20], ...
        'Style', 'javax.swing.jslider', ...
        'ToolTipText', num2str(initialColor(1), '%u'), ...
        'Value', initialColor(1));
    
    sliderGreen = uicomponent(...
        'Background', bColorJava, ...
        'Foreground', fColorJava, ...
        'Minimum', 0, ...
        'Maximum', 255, ...
        'Name', 'sliderGreen', ...
        'Parent', guiSelectColor, ...
        'Position', [10 70 110 20], ...
        'Style', 'javax.swing.jslider', ...
        'ToolTipText', num2str(initialColor(2), '%u'), ...
        'Value', initialColor(2));
    
    sliderBlue = uicomponent(...
        'Background', bColorJava, ...
        'Foreground', fColorJava, ...
        'Minimum', 0, ...
        'Maximum', 255, ...
        'Name', 'sliderBlue', ...
        'Parent', guiSelectColor, ...
        'Position', [10 40 110 20], ...
        'Style', 'javax.swing.jslider', ...
        'ToolTipText', num2str(initialColor(3), '%u'), ...
        'Value', initialColor(3));
    
    %% Create the channel edit boxes.
    editRed = uicontrol(...
        'Background', bColor, ...
        'Callback', {@editcolorcallback, editHex, sliderRed, axesPreview}, ...
        'Foreground', fColor, ...
        'Parent', guiSelectColor, ...
        'Position', [130 100 50 20], ...
        'String', initialColor(1), ...
        'Style', 'edit', ...
        'Tag', 'editRed', ...
        'TooltipString', 'Manually input the red channel value. Use a value in the range 0-255');
    
    editGreen = uicontrol(...
        'Background', bColor, ...
        'Callback', {@editcolorcallback, editHex, sliderGreen, axesPreview}, ...
        'Foreground', fColor, ...
        'Parent', guiSelectColor, ...
        'Position', [130 70 50 20], ...
        'String', initialColor(2), ...
        'Style', 'edit', ...
        'Tag', 'editGreen', ...
        'TooltipString', 'Manually input the green channel value. Use a value in the range 0-255');
    
    editBlue = uicontrol(...
        'Background', bColor, ...
        'Callback', {@editcolorcallback, editHex, sliderBlue, axesPreview}, ...
        'Foreground', fColor, ...
        'Parent', guiSelectColor, ...
        'Position', [130 40 50 20], ...
        'String', initialColor(3), ...
        'Style', 'edit', ...
        'Tag', 'editBlue', ...
        'TooltipString', 'Manually input the blue channel value. Use a value in the range 0-255');
    
    %% Set the slider callbacks, passing the edit box handles.
    set(sliderRed, ...
        'MouseDraggedCallback', {@slidercolorcallback, editHex, editRed, axesPreview}, ...
        'KeyReleasedCallback', {@slidercolorcallback, editHex, editRed, axesPreview}, ...
        'MouseReleasedCallback', {@slidercolorcallback, editHex, editRed, axesPreview})
        
    set(sliderGreen, ...
        'MouseDraggedCallback', {@slidercolorcallback, editHex, editGreen, axesPreview}, ...
        'KeyReleasedCallback', {@slidercolorcallback, editHex, editGreen, axesPreview}, ...
        'MouseReleasedCallback', {@slidercolorcallback, editHex, editGreen, axesPreview})
        
    set(sliderBlue, ...
        'MouseDraggedCallback', {@slidercolorcallback, editHex, editBlue, axesPreview}, ...
        'KeyReleasedCallback', {@slidercolorcallback, editHex, editBlue, axesPreview}, ...
        'MouseReleasedCallback', {@slidercolorcallback, editHex, editBlue, axesPreview})
    
    %% Create the cancel and okay buttons.
    uicontrol(...
        'Background', bColor, ...
        'Callback', {@pushcancel}, ...
        'Foreground', fColor, ...
        'Parent', guiSelectColor, ...
        'Position', [10 10 80 20], ...
        'String', 'Cancel', ...
        'Style', 'pushbutton', ...
        'Tag', 'pushCancel', ...
        'TooltipString', 'Cancel color selection. The previous value will be restored.');
        
    uicontrol(...
        'Background', bColor, ...
        'Callback', {@pushselect}, ...
        'Foreground', fColor, ...
        'Parent', guiSelectColor, ...
        'Position', [100 10 80 20], ...
        'String', 'Select', ...
        'Style', 'pushbutton', ...
        'Tag', 'pushSelect', ...
        'TooltipString', 'Apply the selected color.');
    
    %% Wait on the subfunctions.
    uiwait(guiSelectColor)
    
    %% Resume and return output.
    rgbTriplet = getappdata(guiSelectColor, 'rgbTriplet');
    delete(guiSelectColor)
    
    
    %% Nested function to cancel and return
    function pushcancel(varargin)
        % PUSHCANCEL Cancel color selection and return
        %
        %
        
        %% Return the initial color and close.
        if any(strcmp(selectcolorParser.UsingDefaults, 'initialColor'))
            setappdata(guiSelectColor, 'rgbTriplet', 0)
            
        else
            setappdata(guiSelectColor, 'rgbTriplet', selectcolorParser.Results.initialColor)
            
        end % if
        
        uiresume(guiSelectColor)
    end % pushcancel
    
    
    %% Nested function to return the selected color
    function pushselect(varargin)
        % PUSHSELECT Return the selected color
        %
        %
        
        %% Return the selected color and close.
        setappdata(guiSelectColor, 'rgbTriplet', get(axesPreview, 'Color'))
        uiresume(guiSelectColor)
    end % pushselect
end % selectcolor


%% Create quick color selection patches function
function createquickcolors(editHex, axesPreview, guiSelectColor)
    % CREATEQUICKCOLORS Create the quick color selection 'patches'.
    %
    %
    
    %% Designate the quick colors. These can be edited by users as desired.
    quickColors = [...
        1 0 0; ...
        0 1 0; ...
        0 0 1; ...
        1 1 0; ...
        0 1 1; ...
        1 0 1; ...
        1 0.5 0; ...
        0.5 1 0; ...
        0 1 0.5; ...
        0 0.5 1; ...
        0.5 0 1; ...
        1 0 0.5];
    
    %% Create the quick color patches.
    for c = 1:size(quickColors, 1)
        cPos = [...
            10 + 30*rem(c - 1, 4) ...
            220 - 30 - 30*floor((c - 1)/4) ...
            20 ...
            20];
        
        axes(...
            'Box', 'On', ...
            'ButtonDownFcn', {@axescolorbuttondowncallback, editHex, axesPreview, guiSelectColor}, ...
            'Color', quickColors(c, :), ...
            'Parent', guiSelectColor, ...
            'Units', 'Pixels', ...
            'Position', cPos, ...
            'XColor', [89 89 89]/255, ...
            'XTick', [], ...
            'YColor', [89 89 89]/255, ...
            'YTick', []);
    end % for c
end % createquickcolors


%% Quick color axes' callback
function axescolorbuttondowncallback(axesC, ~, editHex, axesPreview, guiSelectColor)
    % AXESCOLORBUTTONDOWNCALLBACK Update the selected color to the color of
    % the clicked axes
    %
    %
    
    %% Update the preview axes to the clicked quick color axes' color.
    previewColor = get(axesC, 'Color');
    set(axesPreview, 'Color', previewColor)
    
    %% Scale the selected color values to [0, 255].
    redValue = round(255*previewColor(1));
    greenValue = round(255*previewColor(2));
    blueValue = round(255*previewColor(3));
    
    %% Update the hex edit box to match the selected color.
    hexString = transpose(dec2hex([redValue greenValue blueValue], 2));
    set(editHex, 'String', hexString(:)')

    %% Update the sliders.
    sliderRed = findobj(guiSelectColor, 'Name', 'sliderRed');
    set(sliderRed, ...
        'ToolTipText', num2str(redValue), ...
        'Value', redValue)
    
    sliderGreen = findobj(guiSelectColor, 'Name', 'sliderGreen');
    set(sliderGreen, ...
        'ToolTipText', num2str(redValue), ...
        'Value', greenValue)
    
    sliderBlue = findobj(guiSelectColor, 'Name', 'sliderBlue');
    set(sliderBlue, ...
        'ToolTipText', num2str(redValue), ...
        'Value', blueValue)
    
    %% Update the edit boxes.
    editRed = findobj(guiSelectColor, 'Tag', 'editRed');
    set(editRed, 'String', redValue)
    
    editGreen = findobj(guiSelectColor, 'Tag', 'editGreen');
    set(editGreen, 'String', greenValue)
    
    editBlue = findobj(guiSelectColor, 'Tag', 'editBlue');
    set(editBlue, 'String', blueValue)
end % axescolorbuttondowncallback


%% Hex color edit box callback
function edithexcallback(editHex, ~, axesPreview, guiSelectColor)
    % EDITHEXCALLBACK Update the selected color to entered hex code.
    %
    %
    
    %% Validate the input hex code.
    hexString = get(editHex, 'String');
    
    isHex = ~isempty(...
        regexp(hexString, '^([A-Fa-f0-9]{6}|[A-Fa-f0-9]{3})$', 'Start', 'Once'));
    
    if ~isHex
        previewColor = 255*get(axesPreview, 'Color');
        resetString = transpose(dec2hex([previewColor(1) previewColor(2) previewColor(3)], 2));
        set(editHex, 'String', resetString(:)')
        return
    end % if
    
    %% Convert the hex string to RGB triplet components. These are in the range [0, 255].
    redValue = hex2dec(hexString(1:2));
    greenValue = hex2dec(hexString(3:4));
    blueValue = hex2dec(hexString(5:6));
    
    %% Update the preview axes.
    set(axesPreview, 'Color', [redValue, greenValue, blueValue]/255)
    
    %% Update the sliders.
    sliderRed = findobj(guiSelectColor, 'Name', 'sliderRed');
    set(sliderRed, ...
        'ToolTipText', num2str(redValue), ...
        'Value', redValue)
    
    sliderGreen = findobj(guiSelectColor, 'Name', 'sliderGreen');
    set(sliderGreen, ...
        'ToolTipText', num2str(redValue), ...
        'Value', greenValue)
    
    sliderBlue = findobj(guiSelectColor, 'Name', 'sliderBlue');
    set(sliderBlue, ...
        'ToolTipText', num2str(redValue), ...
        'Value', blueValue)
    
    %% Update the edit boxes.
    editRed = findobj(guiSelectColor, 'Tag', 'editRed');
    set(editRed, 'String', redValue)
    
    editGreen = findobj(guiSelectColor, 'Tag', 'editGreen');
    set(editGreen, 'String', greenValue)
    
    editBlue = findobj(guiSelectColor, 'Tag', 'editBlue');
    set(editBlue, 'String', blueValue)
end % edithexcallback


%% Color sliders' callback
function slidercolorcallback(sliderColor, ~, editHex, editColor, axesPreview)
    % SLIDERCOLORCALLBACK Adjust the color channel
    %
    %
    
    %% Scale the current preview color values to [0, 255].
    previewColor = get(axesPreview, 'Color');
    redValue = round(255*previewColor(1));
    greenValue = round(255*previewColor(2));
    blueValue = round(255*previewColor(3));
    
    %% Get the new slider value.
    channelValue = get(sliderColor, 'Value');

    %% Adjust the slider's associated channel.
    switch get(sliderColor, 'Name')
        
        case 'sliderRed'
            redValue = channelValue;
            
        case 'sliderGreen'
            greenValue = channelValue;
            
        case 'sliderBlue'
            blueValue = channelValue;
            
    end % switch
    
    %% Update the preview axes.
    set(axesPreview, 'Color', [redValue greenValue blueValue]/255)

    %% Update the hex edit box to match the selected color.
    hexString = transpose(dec2hex([redValue greenValue blueValue], 2));
    set(editHex, 'String', hexString(:)')

    %% Update the hex edit box.
    hexString = transpose(dec2hex([redValue greenValue blueValue], 2));
    set(editHex, 'String', hexString(:)')

    %% Update the associated edit box.
    set(editColor, 'String', channelValue)    
end % slidercolorcallback


%% Color edit boxes' callback
function editcolorcallback(editColor, ~, editHex, sliderColor, axesPreview)
    % editcolorcallback Edit the color channel value
    %
    %
    
    %% Scale the current preview color values to [0, 255].
    previewColor = get(axesPreview, 'Color');
    redValue = round(255*previewColor(1));
    greenValue = round(255*previewColor(2));
    blueValue = round(255*previewColor(3));
    
    %% Test the input string and reset if invalid.
    editValue = str2double(get(editColor, 'String'));
    
    if ~isnumeric(editValue) || isnan(editValue) || editValue < 0 || editValue > 255
        switch get(editColor, 'Tag')
            
            case 'editRed'
                set(editColor, 'String', redValue)
                
            case 'editGreen'
                set(editColor, 'String', greenValue)
                
            case 'editBlue'
                set(editColor, 'String', blueValue)
                
        end % switch
        
        return
        
    else
        % Round the value before continuing.
        editValue = round(editValue);
        set(editColor, 'String', editValue)
        
    end % if
    
    
    %% Update the edit box's associated color.
    switch get(editColor, 'Tag')
        
        case 'editRed'
            redValue = editValue;
            
        case 'editGreen'
            greenValue = editValue;
            
        case 'editBlue'
            blueValue = editValue;
            
    end % switch
    
    %% Update the preview axes.
    set(axesPreview, 'Color', [redValue greenValue blueValue]/255)

    %% Update the hex edit box.
    hexString = transpose(dec2hex([redValue greenValue greenValue], 2));
    set(editHex, 'String', hexString(:)')

    %% Update the associated slider.
    set(sliderColor, ...
        'Value', editValue, ...
        'ToolTipText', num2str(editValue))
    
    %% Update the preview axes.
    set(axesPreview, 'Color', previewColor)
end % editcolorcallback


%% Key press callback for quickly setting colors using the keyboard
function guiselectcolorkeypresscallback(guiSelectColor, keypressEvent)
    % GUISELECTCOLORKEYPRESSCALLBACK Update the color to a quick key color
    %
    %
    
    %% Check for a key press corresponding to a quick color.
    switch keypressEvent.Key
        
        case 'r'
            previewColor = [1 0 0];
            
        case 'g'
            previewColor = [0 1 0];
          
        case 'b'
            previewColor = [0 0 1];
            
        case 'c'
            previewColor = [0 1 1];
            
        case 'm'
            previewColor = [1 0 1];
            
        case 'y'
            previewColor = [1 1 0];
            
        case 'k'
            previewColor = [0 0 0];
            
        case 'w'
            previewColor = [1 1 1];
            
        case 'o'
            previewColor = [1 0.5 0];
            
        otherwise
            return
            
    end % switch
    
    %% Update the preview axes.
    axesPreview = findobj(guiSelectColor, 'Tag', 'axesPreview');
    set(axesPreview, 'Color', previewColor)
    
    %% Scale the current preview color values to [0, 255].
    redValue = round(255*previewColor(1));
    greenValue = round(255*previewColor(2));
    blueValue = round(255*previewColor(3));
    
    %% Update the hex edit box.
    editHex = findobj(guiSelectColor, 'Tag', 'editHex');
    hexString = transpose(dec2hex([redValue greenValue greenValue], 2));
    set(editHex, 'String', hexString(:)')

    %% Update the sliders.
    sliderRed = findobj(guiSelectColor, 'Name', 'sliderRed');
    set(sliderRed, ...
        'ToolTipText', num2str(redValue), ...
        'Value', redValue)
    
    sliderGreen = findobj(guiSelectColor, 'Name', 'sliderGreen');
    set(sliderGreen, ...
        'ToolTipText', num2str(redValue), ...
        'Value', greenValue)
    
    sliderBlue = findobj(guiSelectColor, 'Name', 'sliderBlue');
    set(sliderBlue, ...
        'ToolTipText', num2str(redValue), ...
        'Value', blueValue)
    
    %% Update the edit boxes.
    editRed = findobj(guiSelectColor, 'Tag', 'editRed');
    set(editRed, 'String', redValue)
    
    editGreen = findobj(guiSelectColor, 'Tag', 'editGreen');
    set(editGreen, 'String', greenValue)
    
    editBlue = findobj(guiSelectColor, 'Tag', 'editBlue');
    set(editBlue, 'String', blueValue)
end % guiselectcolorkeypresscallback

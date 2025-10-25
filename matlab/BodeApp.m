classdef BodeApp < handle
    properties
        F
        Grid
        Left
        Right
        TopLeft
        BottomLeft
        Drop
        Edit
        Btn
        Table
        RightGrid
        AxMag
        AxPh
        CheckZeros
        CheckPoles
        G
        TF
        TFList
        ZeroLinesMag = gobjects(0)
        PoleLinesMag = gobjects(0)
        ZeroLinesPh  = gobjects(0)
        PoleLinesPh  = gobjects(0)
        Tol = 1e-12
        CustomLabel = "custom"
    end
    methods
        function obj = BodeApp
            v = ver('control');
            if isempty(v) || ~license('test','Control_Toolbox')
                error('Control System Toolbox not installed or not licensed.')
            end
            obj.TFList = TransferFunction.makeTransferFunctions();
            obj.F = uifigure('Name','Bode GUI','Position',[100 100 1420 800]);
            obj.Grid = uigridlayout(obj.F,[1 2]); 
            obj.Grid.ColumnWidth = {'0.38x','0.62x'};

            obj.Left = uipanel(obj.Grid); 
            obj.Right = uipanel(obj.Grid);

            gl = uigridlayout(obj.Left,[2 1]); 
            gl.RowHeight = {'0.50x','0.50x'};
            obj.TopLeft = uipanel(gl); obj.BottomLeft = uipanel(gl);
            
            glt = uigridlayout(obj.TopLeft,[3 3]);
            glt.ColumnWidth = {'fit','2x','fit'}; 
            glt.RowHeight = {'fit','fit','fit'};

            uilabel(glt,'Text','Funktion');

            n = length(obj.TFList);
            names = strings(n,1);
            for i = 1:n
                names(i) = string(obj.TFList(i).Name);
            end

            obj.Drop = uidropdown(glt,'Items',[names; obj.CustomLabel],'Value',obj.CustomLabel);
            obj.Btn = uibutton(glt,'Text','Übernehmen');
            uilabel(glt,'Text','custom f(s)=');
            obj.Edit = uieditfield(glt,'text','Value','');
            uilabel(glt,'Text','');

            obj.CheckZeros = uicheckbox(glt,'Text','Nullstellen anzeigen','Value',false);
            uilabel(glt,'Text','');
            obj.CheckPoles = uicheckbox(glt,'Text','Polstellen anzeigen','Value',false);

            obj.Table = uitable(obj.BottomLeft,'ColumnName',{'Typ','Wert'},'Data',cell(0,2));

            obj.RightGrid = uigridlayout(obj.Right,[2 1]); 
            obj.RightGrid.RowHeight = {'1x','1x'};

            obj.AxMag = uiaxes(obj.RightGrid); 
            title(obj.AxMag,'Magnitude (dB)'); 
            xlabel(obj.AxMag,'\omega (rad/s)'); 
            ylabel(obj.AxMag,'|G(j\omega)|_{dB}');

            obj.AxPh  = uiaxes(obj.RightGrid); 
            title(obj.AxPh,'Phase (deg)');     
            xlabel(obj.AxPh,'\omega (rad/s)');  
            ylabel(obj.AxPh,'\angle G(j\omega)');
            obj.Drop.ValueChangedFcn = @(~,~) obj.onChange; %DropDown
            obj.Btn.ButtonPushedFcn  = @(~,~) obj.onApply;  % Submitted
            obj.CheckZeros.ValueChangedFcn = @(src,~) obj.onToggleZeros(src); %ShowZero
            obj.CheckPoles.ValueChangedFcn = @(src,~) obj.onTogglePoles(src); %ShowPoles
            obj.onChange;
        end
        function onChange(obj)
            v = string(obj.Drop.Value);
            if v == obj.CustomLabel
                obj.Edit.Enable = 'on';
                obj.Edit.Editable = 'on';
            else
                obj.Edit.Enable = 'off';
                obj.Edit.Editable = 'off';
                obj.Edit.Value = obj.formelByName(v);
            end
        end
        function onApply(obj)
            try
                v = string(obj.Drop.Value);
                if v == obj.CustomLabel
                    expr = strtrim(string(obj.Edit.Value));
                    if expr == "", uialert(obj.F,'Keine Formel angegeben.','Fehler'); return, end
                    obj.TF = TransferFunction('custom',expr);
                else
                    obj.TF = TransferFunction(v,obj.formelByName(v)); % Can be everytime recreated since we dont mind performance
                    

                end
                obj.G = obj.TF.toTF();
                obj.updateTable;
                obj.updateBode;
            catch ME
                uialert(obj.F,ME.message,'Fehler');
            end
        end
        function onToggleZeros(obj,src)
            if src.Value && ~isempty(obj.G)
                z = zero(obj.G);
                if any(abs(z)<obj.Tol) %Ensure no rounding errors
                    uialert(obj.F,'Eine Nullstelle liegt bei 0 und kann im Bode-Plot nicht angezeigt werden.','Hinweis');
                    display(zero(obj.G));
                end
            end
            obj.updateBode;
        end
        function onTogglePoles(obj,src)
            if src.Value && ~isempty(obj.G)
                p = pole(obj.G);
                if any(abs(p)<obj.Tol)
                    uialert(obj.F,'Eine Polstelle liegt bei 0 und kann im Bode-Plot nicht angezeigt werden.','Hinweis');
                end
            end
            obj.updateBode;
        end
        function updateTable(obj)
            if isempty(obj.G), obj.Table.Data = cell(0,2); return, end
            z = zero(obj.G);
            p = pole(obj.G);
            dz = cell(numel(z),2);
            for i=1:numel(z)

                dz{i,1} = 'Nullstelle';
                dz{i,2} = obj.cfmt(z(i));

            end
            dp = cell(numel(p),2);
            for i=1:numel(p)
                dp{i,1} = 'Pol';
                dp{i,2} = obj.cfmt(p(i));
            end
            obj.Table.Data = [dz; dp];
        end
        function s = cfmt(~,x)
            if abs(imag(x))<1e-12
                
                s = sprintf('%.3g',real(x));
            else
                s = sprintf('%.3g%+ .3gi',real(x),imag(x));
            end
        end
        function updateBode(obj)
            if isempty(obj.G), cla(obj.AxMag); cla(obj.AxPh); return, end
            w = obj.computeOmega();
            H = reshape(freqresp(obj.G,w),[],1);
            mag = 20*log10(abs(H));
            ph = unwrap(angle(H))*180/pi;
            ph = mod(ph + 360, 720) - 360;
            cla(obj.AxMag); cla(obj.AxPh);
            semilogx(obj.AxMag,w,mag,'LineWidth',1); 
            grid(obj.AxMag,'on');

            semilogx(obj.AxPh ,w,ph ,'LineWidth',1); 
            grid(obj.AxPh ,'on');
            yticks(obj.AxPh, -360:45:360)
            obj.drawMarkers;
            xlim(obj.AxMag,[w(1) w(end)]);
            xlim(obj.AxPh ,[w(1) w(end)]);
        end
        function drawMarkers(obj)
            if ~isempty(obj.ZeroLinesMag), delete(obj.ZeroLinesMag); obj.ZeroLinesMag = gobjects(0); end
            if ~isempty(obj.PoleLinesMag), delete(obj.PoleLinesMag); obj.PoleLinesMag = gobjects(0); end
            if ~isempty(obj.ZeroLinesPh ), delete(obj.ZeroLinesPh ); obj.ZeroLinesPh  = gobjects(0); end
            if ~isempty(obj.PoleLinesPh ), delete(obj.PoleLinesPh ); obj.PoleLinesPh  = gobjects(0); end
            if ~isempty(obj.G) && obj.CheckZeros.Value
                z = zero(obj.G);
                wz = abs(z(abs(z)>=obj.Tol)); %again agianst roundingh error
                wz = wz(isfinite(wz) & wz>0);
                for k=1:numel(wz)
                    obj.ZeroLinesMag(end+1) = xline(obj.AxMag,wz(k),'-','Color',[0 0.6 0],'LineWidth',1.4);
                    obj.ZeroLinesPh (end+1) = xline(obj.AxPh ,wz(k),'-','Color',[0 0.6 0],'LineWidth',1.4);
                end
            end
            if ~isempty(obj.G) && obj.CheckPoles.Value
                p = pole(obj.G);
                wp = abs(p(abs(p)>=obj.Tol));
                wp = wp(isfinite(wp) & wp>0);
                for k=1:numel(wp)
                    obj.PoleLinesMag(end+1) = xline(obj.AxMag,wp(k),'-','Color',[0.85 0 0],'LineWidth',1.4);
                    obj.PoleLinesPh (end+1) = xline(obj.AxPh ,wp(k),'-','Color',[0.85 0 0],'LineWidth',1.4);
                end
            end
        end
        function w = computeOmega(obj)
            if isempty(obj.G)
                w = logspace(-2,2,1024);
                return
            end
            p = pole(obj.G);
            z = zero(obj.G);
            f = abs([p; z]);
            f = f(isfinite(f) & f > obj.Tol);
            if isempty(f)
                wmin = 1e-2;
                wmax = 1e2;
            else
                dmin = floor(log10(min(f))) - 2;
                dmax = ceil(log10(max(f))) + 2;
                wmin = max(10^dmin, 1e-2);
                wmax = max(10^dmax, 1e2);
                if wmax <= wmin, wmax = wmin*100; end
            end
            w = logspace(log10(wmin), log10(wmax), 1024);
        end
        function f = formelByName(obj,name)
            idx = find(arrayfun(@(t) t.Name==name, obj.TFList),1,'first');
            if isempty(idx), f = ""; else, f = obj.TFList(idx).Formel; end
        end
    end
end

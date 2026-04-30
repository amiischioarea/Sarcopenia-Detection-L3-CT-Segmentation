clc
clear all
close all

% sursa
caleBaza = uigetdir('C:\Users\User\OneDrive - Technical University of Cluj-Napoca\Desktop\sarcopenia\Baza de date CT sarcopenie', 'Selecteaza folderul sursa');
if caleBaza == 0,  
       error('Nu ai selectat nimic'); 
end

% folder curat pe Desktop
caleOutput = fullfile(char(java.lang.System.getProperty('user.home')), 'Desktop', 'Imagini_L3_Identificate');
if ~exist(caleOutput, 'dir'), mkdir(caleOutput); end

lista = dir(caleBaza);
%ia in calcul doar folderele pacienti
folderePacienti = lista([lista.isdir] & ~startsWith({lista.name}, '.'));

for p = 1:length(folderePacienti)
    numeOriginal = folderePacienti(p).name; % aici este numele pacientului
    fprintf('Se proceseaza pacientul %d/%d: %s\n', p, length(folderePacienti), numeOriginal);
    
    calePacient = fullfile(caleBaza, numeOriginal);
    
    % cauta in toate fisierele unui pacient
    toateFisierele = dir(fullfile(calePacient, '**', '*'));
    fisiere = toateFisierele(~[toateFisierele.isdir]); 
    
    caiDicom = {}; %creeaza o lista goala pt adresele ct - urilor
    semnalOs = []; %pt a vedea cat de densa este coloana vertebrala
    
    for i = 1:length(fisiere)
        caleFisa = fullfile(fisiere(i).folder, fisiere(i).name);
        if isdicom(caleFisa) %pt a vedea daca fisierul e dicom
            try
                info = dicominfo(caleFisa);
                % se exclud imaginile tip "Localizer/Scout"
                if isfield(info, 'ImageType') && contains(lower(char(info.ImageType)), 'localizer')
                    continue; 
                end
                
                %citeste imaginea si o transforma in date numerice
                img = double(dicomread(caleFisa)); % conversia in numeric
                [r, c] = size(img); %definimi zona de cautare
                % detectare densitate coloană pentru L3
                zona = img(round(r*0.55):round(r*0.75), round(c*0.45):round(c*0.55));
                semnalOs(end+1) = mean(zona(:)); % calculul densitatii coloanei 
                %media pixelilor din dreptunghi
                caiDicom{end+1} = caleFisa; %salvarea adresei
            catch
            end
        end
    end
    
    if isempty(semnalOs), continue; end
    
    % se alege felia L3 din imagine
    [~, idx] = max(semnalOs);
    caleL3 = caiDicom{idx};
    
    % procesare medicala pura - fara text
    infoL3 = dicominfo(caleL3);
    imgL3 = double(dicomread(caleL3));
    imgHU = imgL3 * infoL3.RescaleSlope + infoL3.RescaleIntercept;
    
    % Windowing pentru muschi [-29, 150]
    imgHU(imgHU < -29) = -29; 
    imgHU(imgHU > 150) = 150;
    imgFinala = (imgHU - (-29)) / (179);
    
    % numele fisierului contine numele pacientului
    % curatam numele de caractere care nu sunt permise în fisier 
    numeCurat = regexprep(numeOriginal, '[^\w\s-]', ''); 
    numePNG = sprintf('L3_%s.png', numeCurat);
    
    imwrite(imgFinala, fullfile(caleOutput, numePNG));
end

%pentru a incgude folderul gata creat
winopen(caleOutput);
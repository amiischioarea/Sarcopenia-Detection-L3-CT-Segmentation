clc
clear all
close all

load('ModelFinalMuschi_V4.mat'); 

[fisier, cale] = uigetfile('*.png', 'Selectează imaginea CT a pacientului');

if fisier == 0 
    return;
end 

imgOriginala = imread(fullfile(cale, fisier));

% datele pacientului - pentru calcul SMI
genPacient = input('genul pacientului (M/F): ', 's');
inaltime = input('inaltimea pacientului: ');

% preprocesare inteligenta - ii dam inaltimea dorita a pozei
targetSize = [512 832];
imgResized = imresize(imgOriginala, targetSize);

% facem imaginea grayscale - pt compatibilitatea datelor 
if size(imgResized, 3) == 3
    imgGray = rgb2gray(imgResized);
else
    imgGray = imgResized; 
end

% normalizare si pregatire
imgNormalized = adapthisteq(imgGray); 
imgSingle = im2single(imgNormalized);

% segmentare cu AI
scoreMap = predict(net, imgSingle);
maskFinala = scoreMap(:,:,2) > 0.2; % pragul de siguranta 20%
maskFinala = bwareaopen(maskFinala, 1000); % elimina punctele sub 1000 pixeli

% calcul medical 
pixelToCm2 = 0.0025; %aria unui pixel 0.05 
ariaMuschi = sum(maskFinala(:)) * pixelToCm2;
SMI = ariaMuschi / (inaltime^2);

% rezultate vizuale
figure('Name', ['Rezultat Pacient: ', fisier], 'Color', 'w');
% se foloseste imaginea originala ajustata pentru fundal
imgVis = imadjust(imgGray);
out = labeloverlay(imgVis, maskFinala, 'Transparency', 0.3);
imshow(out);
title(['SMI: ', num2str(SMI, '%.2f'), ' cm^2/m^2']);

% diagnostic conform pragurilor de gen
if strcmpi(genPacient, 'M')
    prag = 52.4;
else
    prag = 38.5;
end

if SMI < prag
    status = 'SARCOPENIE (Risc ridicat)';
else
    status = 'NORMAL (Masa musculara adecvata)';
end


% raport 
fprintf('\n========================================\n');
fprintf('           RAPORT MEDICAL AI            \n');
fprintf('========================================\n');
fprintf('Pacient selectat: %s\n', fisier);
fprintf('Arie Musculara:   %.2f cm2\n', ariaMuschi);
fprintf('SMI Calculat:     %.2f cm2/m2\n', SMI);
fprintf('Prag referinta:   %.1f cm2/m2\n', prag);
fprintf('DIAGNOSTIC:       %s\n', status);
fprintf('========================================\n');
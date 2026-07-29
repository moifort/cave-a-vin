# Changelog

## 1.5 (2026.07.29)

### Novidades
- O ecrã Premium abre agora com os números da conta: as digitalizações usadas, as que restam e a data de renovação da quota.
- A ficha de uma garrafa arrumada indica agora a sua posição na garrafeira.

### Correções
- Uma subscrição comprada na App Store é agora ativada assim que é paga.
- Uma garrafa é agora arrumada na posição escolhida, e não na do lado.
- A grelha mostrada para mover uma garrafa tem agora as dimensões da garrafeira.
- Alguns textos não seguiam o idioma da aplicação e apareciam sempre em francês. Está corrigido no painel, nas mensagens de carregamento e nas definições.

## 1.4 (2026.07.22)

### Novidades
- A digitalização de rótulos dispõe agora de uma quota mensal de cinco digitalizações gratuitas. Quando a quota do mês se esgota, o ecrã de digitalização propõe o Vinarium Premium. Todo o resto da aplicação continua gratuito e sem limite.
- O Vinarium Premium desbloqueia a digitalização ilimitada, com um plano mensal ou um plano anual que começa com sete dias grátis. A oferta encontra-se nas Definições, e a subscrição gere-se a partir da conta App Store.

### Desempenho
- O painel abre mais depressa.

## 1.3 (2026.07.18)

### Novidades
- Durante uma digitalização, o rótulo fotografado permanece no ecrã com uma animação enquanto a análise decorre, em vez de um ecrã de carregamento vazio.
- Quando uma digitalização não reconhece nenhum rótulo, um ecrã claro indica-o e propõe tentar de novo, em vez de abrir uma ficha vazia.
- A adega partilhada reúne agora o seu valor total, os seus avisos de garrafas prontas a beber e o seu diário para todo o agregado. Cada movimento do diário mostra o membro que lhe deu origem.

## 1.2 (2026.07.16)

### Novidades
- O tamanho da adega pode agora ser alterado nas Definições, partindo de um modelo ou definindo o número de filas e espaços. As garrafas permanecem no seu lugar.
- As garrafas da adega partilhada são agora acessíveis à pesquisa. As de todo o agregado aparecem na lista e na pesquisa, com o nome do seu proprietário.
- O nome aparece no perfil.

### Correções
- As ligações de convite abrem agora a aplicação de forma fiável.

## 1.1 (2026.07.15)

### Novidades
- Um fluxo de configuração no primeiro arranque pede o nome e depois as dimensões da adega (número de filas e espaços). O modelo pode ser escolhido num catálogo de garrafeiras do mercado, com pesquisa por marca ou modelo, para um dimensionamento automático, ou as dimensões são inseridas à mão. O número de zonas de temperatura também é guardado.
- O tamanho da adega deixou de ser fixo. Corresponde às dimensões escolhidas na configuração, e tanto a grelha de colocação como a capacidade apresentada se adaptam a elas.
- A barra de separadores reduz-se automaticamente ao deslizar para ampliar a área de conteúdo, e o botão Digitalizar permanece fixo à direita.
- No ecrã de início de sessão, o logótipo anima-se ao abrir, com um mosaico de cápsulas nas cores da aplicação que aparece em cascata.
- Abrir uma ligação de convite inicia agora a aplicação diretamente no ecrã que permite juntar-se ao agregado. Se a aplicação não estiver instalada, a página propõe transferi-la da App Store.
- Cada código de convite mostra um emblema «Pendente».

### Correções
- As ações Copiar ligação, E-mail e Revogar acionam-se agora de forma independente. Um único toque já não dispara as três ao mesmo tempo.

## 1.0 (2026.07.11)

### Novidades
- Partilha da adega: as pessoas do agregado são convidadas com um código para partilhar uma única adega comum. Cada um mantém a sua biblioteca, as suas notas de prova e o seu diário, e apenas as garrafas na adega são postas em comum.
- Numa adega partilhada, todas as garrafas do agregado aparecem na mesma grelha, com o nome do proprietário nas dos outros. Qualquer membro pode colocar, mover, consumir ou oferecer qualquer garrafa. A saída é registada no diário do proprietário do vinho, e cada nota de prova continua a ser a do seu autor.
- Na ficha de um vinho pertencente a outro membro é mostrado o nome do proprietário e as ações reservadas como editar, eliminar e recomendar ficam ocultas.
- Uma lupa na barra de ferramentas abre uma pesquisa em ecrã inteiro. Pode escrever-se um nome de vinho, um produtor, uma colheita ou uma pessoa, e os resultados são ordenados por relevância e agrupados com clareza, por exemplo na adega, já bebidos, ofertas ou recomendados. Sobre os resultados são oferecidos filtros combináveis (cor, tipo, favorito, na adega, ofertas).
- As listas assinalam num relance as garrafas na adega com um ícone de armário.
- As vistas Oferecidos e Recomendados oferecem uma nova ordenação «Por pessoa» que agrupa a lista por quem oferece ou recomenda.
- Ao digitalizar, a janela de adicionar propõe agora apenas «Guardar na adega» e «Apenas registar». O favorito e a recomendação definem-se agora diretamente na ficha.
- Todas as bebidas têm agora subtipos estruturados (rum, porto, cerveja loura, saqué espumante e mais), propostos nos formulários e preenchidos pela análise de IA.
- A cor de um vinho volta a ser a sua cor (tinto, branco ou rosé). Espumante e Meio-doce passam a subtipos do vinho.
- No painel, o widget «Na adega» mostra a ocupação da adega, com as garrafas colocadas sobre a capacidade total (por exemplo 41/48) e o total em tamanho menor.
- O ecrã de Definições é acessível a partir do painel com um ícone no canto superior esquerdo.
- Um perfil de utilizador permite terminar a sessão.
- A versão da aplicação e o histórico do changelog podem ser consultados.
- É mostrada a informação da adega (dimensões e número de garrafas colocadas).
- Os dados podem ser exportados e importados em formato JSON.

### Correções
- A lista «Os meus vinhos» volta a ser mostrada em vez de uma mensagem de erro.

### Desempenho
- As listas, a pesquisa e o painel são mais rápidos. O servidor agrupa e partilha as suas leituras, sem nunca recarregar várias vezes os mesmos vinhos nem percorrer toda a adega para um simples filtro.
- A abertura da ficha detalhada é muito mais rápida. O servidor lê agora apenas a informação do vinho consultado em vez de percorrer toda a adega.

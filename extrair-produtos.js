/* Extrai os produtos do catálogo aberto no navegador e baixa um CSV pronto para importar no painel.
   Use na página do catálogo (meucomercio.com.br/mercadomezzomo), no Console (F12). */
(async()=>{
  const cat=(prompt('Categoria dos produtos desta tela (deixe vazio para não definir):','')||'').trim().toUpperCase();
  const K='mz_prod';let db={};try{db=JSON.parse(localStorage.getItem(K)||'{}')}catch(e){}
  const sleep=t=>new Promise(r=>setTimeout(r,t));
  const isCod=e=>e.children.length==0&&/\(\s*C[óo]digo\s*:?\s*[\w.-]+\s*\)/i.test(e.textContent);
  const codes=()=>[...document.querySelectorAll('*')].filter(isCod);
  let last=-1,same=0;
  while(same<3){
    scrollTo(0,document.body.scrollHeight);
    document.querySelectorAll('*').forEach(e=>{if(e.scrollHeight>e.clientHeight+50&&/auto|scroll/.test(getComputedStyle(e).overflowY))e.scrollTop=e.scrollHeight});
    [...document.querySelectorAll('button,a')].filter(b=>/mais produtos|ver mais|carregar mais|mostrar mais/i.test(b.textContent)).forEach(b=>b.click());
    await sleep(1500);
    const n=codes().length;same=n==last?same+1:0;last=n;
  }
  let n=0;
  codes().forEach(el=>{
    let card=el;
    while(card.parentElement&&[...card.parentElement.querySelectorAll('*')].filter(isCod).length<2)card=card.parentElement;
    const tx=card.innerText,t=tx.split('\n').map(x=>x.trim()).filter(Boolean);
    const cm=tx.match(/C[óo]digo\s*:?\s*([\w.-]+)/i),pm=tx.match(/R\$\s*([\d.]+,\d{2})/);
    const nm=t.find(x=>!/C[óo]digo/i.test(x)&&!/R\$/.test(x)&&x.length>2);
    if(!cm||!pm||!nm)return;
    const im=card.querySelector('img'),src=im?(im.currentSrc||im.src||im.dataset.src||''):'',cod=cm[1];
    db[cod]={n:nm.replace(/;/g,','),p:pm[1],c:cat||(db[cod]&&db[cod].c)||'',cod,u:'un',img:/^https?:/.test(src)?src:''};n++;
  });
  localStorage.setItem(K,JSON.stringify(db));
  const rows=Object.values(db);
  const csv='\uFEFFnome;preço;categoria;código;unidade;foto\n'+rows.map(r=>[r.n,r.p,r.c,r.cod,r.u,r.img].join(';')).join('\n');
  const a=document.createElement('a');a.href=URL.createObjectURL(new Blob([csv],{type:'text/csv;charset=utf-8'}));a.download='produtos-mezzomo.csv';a.click();
  alert(n+' produtos lidos nesta tela. Total acumulado: '+rows.length+'. O arquivo produtos-mezzomo.csv foi baixado.');
})();

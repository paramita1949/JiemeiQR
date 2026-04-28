const fs = require('fs');
const path = require('path');

const penPath = path.resolve(__dirname, '..', 'untitled.pen');
const raw = fs.readFileSync(penPath, 'utf8');
const doc = JSON.parse(raw);

const prefix = 'JIEMEI REAL 2026-04-28';
doc.children = (doc.children || []).filter(
  (node) => !(node.name || '').startsWith(prefix),
);

let idSeq = 0;
const id = () => `r${(idSeq++).toString(36).padStart(5, '0')}`;
const phoneW = 390;
const phoneH = 844;
const bg = '#F3F5FA';
const blue = '#0B5FFF';
const text = '#111827';
const muted = '#6B7280';
const light = '#F7F9FC';

function frame(props, children = []) {
  return { type: 'frame', id: id(), ...props, children };
}

function txt(content, props = {}) {
  return {
    type: 'text',
    id: id(),
    fill: props.fill || text,
    content,
    fontFamily: 'Inter',
    fontSize: props.fontSize ?? 14,
    fontWeight: props.fontWeight ?? '700',
    ...props,
  };
}

function icon(name, props = {}) {
  return {
    type: 'icon_font',
    id: id(),
    width: props.size || 24,
    height: props.size || 24,
    iconFontName: name,
    iconFontFamily: 'Material Symbols Rounded',
    fill: props.fill || blue,
    ...props,
  };
}

function statusBar() {
  return frame(
    {
      name: 'statusBar',
      width: 'fill_container',
      height: 38,
      justifyContent: 'space_between',
      alignItems: 'center',
    },
    [
      txt('06:06', { fontSize: 14, fontWeight: '800' }),
      txt('VPN  5G  5G  WiFi', { fontSize: 10, fill: '#1F2937' }),
    ],
  );
}

function titleBlock(iconName, title, subtitle, trailing) {
  const row = [
    frame(
      {
        name: 'titleIcon',
        width: 38,
        height: 38,
        fill: blue,
        cornerRadius: 9,
        justifyContent: 'center',
        alignItems: 'center',
      },
      [icon(iconName, { fill: '#FFFFFF', size: 24 })],
    ),
    txt(title, { fontSize: 34, fontWeight: '900' }),
  ];
  if (trailing) {
    row.push(frame({ width: 'fill_container' }));
    row.push(trailing);
  }
  return frame({ name: 'titleBlock', width: 'fill_container', layout: 'vertical', gap: 7 }, [
    frame({ width: 'fill_container', gap: 10, alignItems: 'center' }, row),
    txt(subtitle, { fontSize: 14, fill: muted, fontWeight: '500' }),
  ]);
}

function card(children, props = {}) {
  return frame(
    {
      width: 'fill_container',
      fill: '#FFFFFF',
      cornerRadius: 18,
      layout: 'vertical',
      gap: props.gap ?? 10,
      padding: props.padding ?? 16,
      ...props,
    },
    children,
  );
}

function input(label, props = {}) {
  return frame(
    {
      width: props.width || 'fill_container',
      height: props.height || 54,
      fill: light,
      cornerRadius: 12,
      padding: [14, 13],
      alignItems: 'center',
    },
    [txt(label, { fontSize: props.fontSize ?? 17, fill: '#4B5563', fontWeight: '500' })],
  );
}

function button(label, props = {}) {
  return frame(
    {
      width: props.width || 'fill_container',
      height: props.height || 48,
      fill: props.fill || blue,
      stroke: props.stroke,
      strokeThickness: props.strokeThickness,
      cornerRadius: props.cornerRadius ?? 10,
      justifyContent: 'center',
      alignItems: 'center',
      gap: 7,
      padding: 10,
    },
    [
      ...(props.icon ? [icon(props.icon, { fill: props.textFill || '#FFFFFF', size: 18 })] : []),
      txt(label, { fill: props.textFill || '#FFFFFF', fontSize: props.fontSize ?? 16, fontWeight: '800' }),
    ],
  );
}

function chip(label, selected = false, props = {}) {
  return frame(
    {
      height: props.height || 38,
      width: props.width,
      fill: selected ? (props.fill || blue) : '#FFFFFF',
      stroke: selected ? (props.stroke || blue) : '#D5DDEB',
      strokeThickness: 1,
      cornerRadius: props.radius ?? 999,
      padding: [14, 9],
      justifyContent: 'center',
      alignItems: 'center',
    },
    [txt(label, { fill: selected ? (props.textFill || '#FFFFFF') : (props.textFill || '#111827'), fontSize: props.fontSize ?? 15, fontWeight: '800' })],
  );
}

function screen(name, x, children) {
  return frame(
    {
      name: `${prefix} ${name}`,
      x,
      y: 4930,
      width: phoneW,
      height: phoneH,
      clip: true,
      fill: bg,
      layout: 'vertical',
      gap: 12,
      padding: 20,
    },
    [statusBar(), ...children],
  );
}

function hero(total, extra) {
  return frame(
    {
      width: 'fill_container',
      height: extra ? 118 : 112,
      fill: '#1265F8',
      cornerRadius: 18,
      layout: 'vertical',
      gap: 8,
      padding: 16,
    },
    [
      txt('总库存', { fill: '#DBEAFE', fontSize: 13, fontWeight: '800' }),
      txt(total, { fill: '#FFFFFF', fontSize: 34, fontWeight: '900' }),
      ...(extra ? [txt(extra, { fill: '#DBEAFE', fontSize: 13, fontWeight: '600' })] : []),
    ],
  );
}

const screens = [];

screens.push(screen('01 首页总控', -50, [
  titleBlock('warehouse', '洁美', '浙江仓订单与库存工作台'),
  hero('3,155,730 件', '今日订单 0 单 · 昨日订单 0 单 · 未完成 0 单'),
  txt('常用功能', { fontSize: 18, fontWeight: '900' }),
  frame({ width: 'fill_container', layout: 'vertical', gap: 10 }, [
    featureRow([
      ['qr_code_scanner', 'QR箱码', '批量预览与自动滚动', '#EAF1FF'],
      ['receipt_long', '订单信息', '运单状态与产品明细', '#F3EEFF'],
    ]),
    featureRow([
      ['calendar_month', '出库日历', '按日期回看库存', '#ECFDF3'],
      ['inventory_2', '库存明细', '批号库存与备注', '#FFF4E8'],
    ]),
    featureRow([
      ['sync_alt', '局域网迁移', '发送 / 接收数据库', '#EAF7FF'],
      ['edit_document', '基础资料', '产品/批号/规格/库位', '#EEF2FF'],
    ]),
  ]),
]));

function featureRow(items) {
  return frame({ width: 'fill_container', height: 100, gap: 12 }, items.map(([ic, t, s, fill]) =>
    frame({ width: 'fill_container', height: 'fill_container', fill, cornerRadius: 14, layout: 'vertical', gap: 6, padding: 14 }, [
      icon(ic, { size: 24 }),
      txt(t, { fontSize: 17, fontWeight: '900' }),
      txt(s, { fontSize: 12, fill: muted, fontWeight: '500' }),
    ]),
  ));
}

screens.push(screen('02 基础资料', 370, [
  titleBlock('edit_document', '基础资料', '', frame({ width: 48, height: 48, fill: blue, cornerRadius: 24, justifyContent: 'center', alignItems: 'center' }, [icon('qr_code_scanner', { fill: '#FFFFFF' })])),
  card([
    input('产品编号'),
    input('产品名称'),
    frame({ width: 'fill_container', gap: 12 }, [input('批号', { width: 'fill_container' }), input('日期', { width: 'fill_container' })]),
    input('数量'),
    frame({ width: 'fill_container', gap: 12 }, [input('每板箱数', { width: 'fill_container' }), input('每箱件数', { width: 'fill_container' })]),
    input('库位'),
    input('备注', { height: 72 }),
    frame({ width: 'fill_container', justifyContent: 'space_between', alignItems: 'center' }, [
      txt('TS扫码', { fontSize: 15, fill: muted, fontWeight: '900' }),
      frame({ width: 150, height: 44, fill: '#FFFFFF', stroke: '#6B7280', cornerRadius: 22, gap: 0 }, [
        frame({ width: 75, height: 44, fill: '#DDE3FF', cornerRadius: 22, justifyContent: 'center', alignItems: 'center' }, [txt('否', { fontSize: 16, fill: '#4B5563' })]),
        frame({ width: 75, height: 44, justifyContent: 'center', alignItems: 'center' }, [txt('是', { fontSize: 16 })]),
      ]),
    ]),
  ], { gap: 12 }),
  frame({ width: 'fill_container', gap: 12 }, [
    button('继续录入', { fill: '#FFFFFF', textFill: blue, stroke: '#6B7280', strokeThickness: 1, width: 'fill_container' }),
    button('保存', { width: 'fill_container' }),
  ]),
]));

screens.push(screen('03 局域网迁移', 790, [
  titleBlock('sync_alt', '局域网迁移', '数据库发送、接收与备份'),
  transferCard('upload_file', '发送数据库', '启动局域网发送服务，提供配对码供另一台设备接收。', '开始发送'),
  transferCard('download', '接收数据库', '从另一台设备接收数据库，导入前自动备份当前数据库。', '开始接收', '粘贴连接码'),
  transferCard('download', '本地备份', '备份/导入只在此页面处理', '生成备份', 'jiemei-backup-20260428-060632.sqlite'),
]));

function transferCard(ic, title, desc, primary, secondary) {
  return card([
    frame({ width: 'fill_container', gap: 12 }, [
      frame({ width: 44, height: 44, fill: '#EAF7FF', cornerRadius: 12, justifyContent: 'center', alignItems: 'center' }, [icon(ic)]),
      frame({ width: 'fill_container', layout: 'vertical', gap: 8 }, [
        txt(title, { fontSize: 19, fontWeight: '900' }),
        txt(desc, { fontSize: 13, fill: muted, fontWeight: '700' }),
        ...(secondary && secondary.endsWith('.sqlite') ? [txt(secondary, { fontSize: 13, fill: blue, fontWeight: '800' })] : []),
        frame({ width: 'fill_container', gap: 10 }, [
          button(primary, { width: 128 }),
          ...(secondary && !secondary.endsWith('.sqlite') ? [button(secondary, { width: 146, fill: '#FFFFFF', textFill: blue, stroke: '#6B7280', strokeThickness: 1 })] : []),
        ]),
      ]),
    ]),
  ]);
}

screens.push(screen('04 库存明细', 1210, [
  titleBlock('inventory_2', '库存明细', '批号库存、规格、备注', button('录入', { width: 108, icon: 'add' })),
  hero('3,155,730 件'),
  card([
    frame({ width: 'fill_container', height: 54, fill: light, cornerRadius: 12, padding: [14, 12], gap: 10, alignItems: 'center' }, [icon('search', { fill: '#4B5563' }), txt('筛选产品 / 批号', { fontSize: 17, fill: '#4B5563', fontWeight: '500' })]),
    frame({ width: 'fill_container', gap: 10 }, ['72067', '72068', '20854', '20148'].map((v) => chip(v, false, { textFill: '#6B7280' }))),
    frame({ width: 'fill_container', justifyContent: 'center' }, [
      frame({ width: 232, height: 46, stroke: '#6B7280', cornerRadius: 23, gap: 0 }, [
        chip('全部', false, { radius: 0, height: 46 }),
        chip('有库存', true, { fill: '#DDE3FF', textFill: '#374151', radius: 0, height: 46 }),
        chip('零库存', false, { radius: 0, height: 46 }),
      ]),
    ]),
  ], { gap: 12 }),
  frame({ width: 'fill_container', layout: 'vertical', gap: 20 }, ['72067  2,359,140件 · 78,638箱', '72068  247,080件 · 6,177箱', '20854  195,330件 · 6,511箱', '20148  168,420件 · 5,614箱', '20380  90,930件 · 3,031箱', '19723  30,960件 · 1,032箱'].map((v) =>
    frame({ width: 'fill_container', gap: 8, alignItems: 'center' }, [txt('›', { fontSize: 24, fill: muted }), txt(v, { fontSize: 16, fill: '#4B5563', fontWeight: '900' })]),
  )),
]));

screens.push(screen('05 出库日历', 1630, [
  titleBlock('calendar_month', '出库日历', '按日期查看出库与订单'),
  hero('3,155,730 件'),
  frame({ width: 'fill_container', gap: 10 }, [chip('今日'), chip('昨日'), chip('一周'), chip('一月'), frame({ width: 46, height: 46, fill: '#DDE3FF', cornerRadius: 23, justifyContent: 'center', alignItems: 'center' }, [icon('calendar_month', { fill: '#4B5563' })])]),
  txt('2026.4.28', { fontSize: 18, fontWeight: '900' }),
  card([txt('订单 0单 · 0箱', { fontSize: 21, fontWeight: '900' }), txt('暂无订单', { fontSize: 15, fill: muted, fontWeight: '500' })]),
  card([txt('当日出库明细', { fontSize: 21, fontWeight: '900' }), txt('暂无出库', { fontSize: 15, fill: muted, fontWeight: '500' })]),
  frame({ width: 'fill_container', gap: 12 }, [button('查看订单信息', { width: 'fill_container' }), button('查看库存明细', { width: 'fill_container', fill: '#FFFFFF', textFill: blue, stroke: '#6B7280', strokeThickness: 1 })]),
]));

screens.push(screen('06 订单信息', 2050, [
  titleBlock('receipt_long', '订单信息', '2026.4.28 周二', frame({ width: 48, height: 48, fill: '#DDE3FF', cornerRadius: 24, justifyContent: 'center', alignItems: 'center' }, [icon('calendar_month', { fill: '#4B5563' })])),
  frame({ width: 'fill_container', gap: 10 }, [chip('今日', true, { textFill: blue, fill: '#FFFFFF', stroke: blue }), chip('昨日'), chip('一周'), chip('一月'), chip('未完成')]),
  frame({ width: 'fill_container', gap: 10 }, [
    chip('全部', true, { width: 'fill_container' }),
    chip('未完成', false, { width: 'fill_container', textFill: '#F97316', stroke: '#FDBA74' }),
    chip('已拣货', false, { width: 'fill_container', textFill: blue, stroke: '#BFDBFE' }),
    chip('完成', false, { width: 'fill_container', textFill: '#16A34A', stroke: '#BBF7D0' }),
  ]),
  txt('完成 0单 · 未完成 0单', { fontSize: 15, fill: muted, fontWeight: '900' }),
  button('新增运单', { icon: 'add' }),
  frame({ width: 'fill_container', height: 260, justifyContent: 'center', alignItems: 'center' }, [txt('暂无订单', { fontSize: 16, fill: muted })]),
]));

screens.push(screen('07 新增运单', 2470, [
  titleBlock('add_box', '新增运单', '商家、产品、批号、箱数录入'),
  card([txt('订单信息', { fontSize: 20, fontWeight: '900' }), input('运单号'), input('商家'), chip('2026.4.28', true, { fill: '#DDE3FF', textFill: '#374151' })], { gap: 12 }),
  card([
    txt('产品明细', { fontSize: 20, fontWeight: '900' }),
    txt('产品', { fontSize: 12, fill: '#4B5563', fontWeight: '600' }),
    input('72067  78638箱'),
    txt('批号', { fontSize: 12, fill: '#4B5563', fontWeight: '600' }),
    input('FCGBKEZ · 2029.9.6'),
    input('箱数'),
    frame({ width: 'fill_container', gap: 10 }, [chip('可用 333箱', true, { fill: '#EFF6FF', textFill: blue }), chip('35箱/板 · 30件/箱', true, { fill: '#EFF6FF', textFill: blue }), chip('TS', true, { fill: '#FEE2E2', textFill: '#DC2626' })]),
  ], { gap: 10 }),
  frame({ width: 'fill_container', gap: 12 }, [button('继续添加', { width: 'fill_container', fill: '#FFFFFF', textFill: blue, stroke: '#6B7280', strokeThickness: 1 }), button('完成', { width: 'fill_container' })]),
]));

screens.push(screen('08 QR箱码生成', 2890, [
  titleBlock('qr_code_scanner', 'QR箱码生成', '扫描后配置生成规则'),
  card([txt('扫码 / 本地图片识别', { fontSize: 20, fontWeight: '900' }), txt('支持相机与本地图片导入', { fontSize: 14, fill: muted, fontWeight: '500' }), frame({ width: 'fill_container', gap: 12 }, [button('开始扫码', { width: 'fill_container', icon: 'photo_camera' }), button('导入图片', { width: 'fill_container', icon: 'image' })])], { fill: '#EAF7FF' }),
  card([
    txt('生成参数', { fontSize: 20, fontWeight: '900' }),
    frame({ width: 'fill_container', gap: 12 }, [button('数量: 100', { width: 'fill_container', fill: '#FFFFFF', textFill: blue, stroke: '#6B7280', strokeThickness: 1 }), button('自动滑动: 1.0s', { width: 'fill_container', fill: '#FFFFFF', textFill: blue, stroke: '#6B7280', strokeThickness: 1 })]),
    frame({ width: 'fill_container', gap: 10 }, [chip('顺序'), chip('✓  随机', true, { fill: '#DDE3FF', textFill: '#374151' }), chip('✓  末3位随机', true, { fill: '#DDE3FF', textFill: '#374151' })]),
    frame({ width: 'fill_container', gap: 10 }, [chip('末4位随机')]),
  ], { fill: '#F3EEFF', gap: 16 }),
  frame({ width: 'fill_container', gap: 12 }, [button('生成并预览', { width: 'fill_container', fill: '#D1D5DB', textFill: '#9CA3AF', icon: 'play_arrow' }), button('下一组继续', { width: 'fill_container', fill: '#D1D5DB', textFill: '#9CA3AF', icon: 'skip_next' })]),
  txt('当前预览: 未扫描', { fontSize: 17, fontWeight: '900' }),
  txt('提示: 请先扫描箱贴码或导入图片，再生成预览', { fontSize: 14, fill: '#B91C1C', fontWeight: '600' }),
]));

doc.children.push(...screens);
fs.writeFileSync(penPath, JSON.stringify(doc, null, 2), 'utf8');
console.log(`Updated ${penPath} with ${screens.length} real UI baseline screens.`);

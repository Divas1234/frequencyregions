import bpy

try:
    # 定义顶点坐标
    verts = [(0, 0, 0), (1, 0, 0), (1, 1, 0), (0, 1, 0)]

    # 定义面，使用顶点索引
    faces = [(0, 1, 2, 3)]

    # 创建一个新的网格数据块
    mesh = bpy.data.meshes.new("SimpleQuad")

    # 从顶点和面创建网格
    mesh.from_pydata(verts, [], faces)

    # 更新网格几何体
    mesh.update()

    # 创建一个新的对象
    obj = bpy.data.objects.new("SimpleQuadObject", mesh)

    # 将对象链接到场景
    bpy.context.collection.objects.link(obj)
    
    # 选择新创建的对象
    bpy.ops.object.select_all(action='DESELECT')
    obj.select_set(True)
    bpy.context.view_layer.objects.active = obj
    
    # 打印成功消息
    print("成功创建了简单四边形对象：", obj.name)
    
except Exception as e:
    print("创建四边形时出错：", str(e))

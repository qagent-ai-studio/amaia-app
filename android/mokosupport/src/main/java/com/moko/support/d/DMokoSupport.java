package com.moko.support.d;

import android.bluetooth.BluetoothDevice;
import android.bluetooth.BluetoothGatt;
import android.bluetooth.BluetoothGattCharacteristic;
import android.content.Context;

import com.elvishew.xlog.XLog;
import com.moko.ble.lib.MokoBleLib;
import com.moko.ble.lib.MokoBleManager;
import com.moko.ble.lib.MokoConstants;
import com.moko.ble.lib.event.ConnectStatusEvent;
import com.moko.ble.lib.event.OrderTaskResponseEvent;
import com.moko.ble.lib.task.OrderTask;
import com.moko.ble.lib.task.OrderTaskResponse;
import com.moko.support.d.entity.ExportData;
import com.moko.support.d.entity.OrderCHAR;
import com.moko.support.d.handler.MokoCharacteristicHandler;

import com.moko.support.d.task.PasswordTask;
import com.moko.support.d.task.ParamsTask;

import org.greenrobot.eventbus.EventBus;

import java.util.ArrayList;
import java.util.HashMap;
import java.util.UUID;

public class DMokoSupport extends MokoBleLib {
    private HashMap<OrderCHAR, BluetoothGattCharacteristic> mCharacteristicMap;

    private static volatile DMokoSupport INSTANCE;

    private Context mContext;

    private MokoBleConfig mBleConfig;

    private String mPassword = "";

    private DMokoSupport() {
        //no instance
    }

    public void setPassword(String password) {
        mPassword = password != null ? password : "";
        if (mBleConfig != null) {
            mBleConfig.setPassword(mPassword);
        }
    }

    public static DMokoSupport getInstance() {
        if (INSTANCE == null) {
            synchronized (DMokoSupport.class) {
                if (INSTANCE == null) {
                    INSTANCE = new DMokoSupport();
                }
            }
        }
        return INSTANCE;
    }

    public void init(Context context) {
        mContext = context;
        super.init(context);
    }

    public MokoBleConfig getMokoBleConfig() {
        return mBleConfig;
    }

    public void writePasswordDirectly(byte[] data) {
        if (mBleConfig != null) {
            mBleConfig.writeDirectly(mBleConfig.getPasswordCharacteristic(), data);
        }
    }


    @Override
    public MokoBleManager getMokoBleManager() {
        mBleConfig = new MokoBleConfig(mContext, this);
        if (mPassword != null && !mPassword.isEmpty()) {
            mBleConfig.setPassword(mPassword);
        }
        return mBleConfig;
    }

    ///////////////////////////////////////////////////////////////////////////
    // connect
    ///////////////////////////////////////////////////////////////////////////

    @Override
    public void onDeviceConnected(BluetoothGatt gatt) {
        mCharacteristicMap = new MokoCharacteristicHandler().getCharacteristics(gatt);
        ConnectStatusEvent connectStatusEvent = new ConnectStatusEvent();
        connectStatusEvent.setAction(MokoConstants.ACTION_DISCOVER_SUCCESS);
        EventBus.getDefault().post(connectStatusEvent);
    }

    @Override
    public void onDeviceDisconnected(BluetoothDevice device) {
        ConnectStatusEvent connectStatusEvent = new ConnectStatusEvent();
        connectStatusEvent.setAction(MokoConstants.ACTION_DISCONNECTED);
        EventBus.getDefault().post(connectStatusEvent);
    }

    @Override
    public BluetoothGattCharacteristic getCharacteristic(Enum orderCHAR) {
        return mCharacteristicMap.get(orderCHAR);
    }

    ///////////////////////////////////////////////////////////////////////////
    // order
    ///////////////////////////////////////////////////////////////////////////

    @Override
    public boolean isCHARNull() {
        if (mCharacteristicMap == null || mCharacteristicMap.isEmpty()) {
            disConnectBle();
            return true;
        }
        return false;
    }

    @Override
    public void orderFinish() {
        OrderTaskResponseEvent event = new OrderTaskResponseEvent();
        event.setAction(MokoConstants.ACTION_ORDER_FINISH);
        EventBus.getDefault().post(event);
    }

    @Override
    public void orderTimeout(OrderTaskResponse response) {
        android.util.Log.e("MkButtonSDK", "!!! ORDER TIMEOUT !!! This may cause disconnection");
        android.util.Log.e("MkButtonSDK", "Response: " + response);
        if (response != null && response.responseValue != null) {
            android.util.Log.e("MkButtonSDK", "Response value: " + com.moko.ble.lib.utils.MokoUtils.bytesToHexString(response.responseValue));
        }
        OrderTaskResponseEvent event = new OrderTaskResponseEvent();
        event.setAction(MokoConstants.ACTION_ORDER_TIMEOUT);
        event.setResponse(response);
        EventBus.getDefault().post(event);
    }

    @Override
    public void orderResult(OrderTaskResponse response) {
        OrderTaskResponseEvent event = new OrderTaskResponseEvent();
        event.setAction(MokoConstants.ACTION_ORDER_RESULT);
        event.setResponse(response);
        EventBus.getDefault().post(event);
    }

    @Override
    public boolean orderResponseValid(BluetoothGattCharacteristic characteristic, OrderTask orderTask) {
        final UUID responseUUID = characteristic.getUuid();
        final OrderCHAR orderCHAR = (OrderCHAR) orderTask.orderCHAR;
        return responseUUID.equals(orderCHAR.getUuid());
    }


    @Override
    public boolean orderNotify(BluetoothGattCharacteristic characteristic, byte[] value) {
        final UUID responseUUID = characteristic.getUuid();
        android.util.Log.d("MkButtonSDK", "orderNotify uuid=" + responseUUID.toString() + 
            " value=" + com.moko.ble.lib.utils.MokoUtils.bytesToHexString(value));

        // Procesar respuestas de inicialización desde CHAR_PARAMS
        if (responseUUID.equals(OrderCHAR.CHAR_PARAMS.getUuid()) && value != null && value.length >= 3 &&
            (value[0] & 0xFF) == 0xEB && (value[1] & 0xFF) == 0x00) {
            int key = value[2] & 0xFF;
            android.util.Log.d("MkButtonSDK", "PARAMS init response key=0x" + String.format("%02X", key));
            
            // Respuestas esperadas durante inicialización:
            // 0x57 = Confirmación de autenticación
            // 0x2C = Respuesta de configuración (nombre modelo: "BXP-B-D")
            // 0x51 = Respuesta de estado con nombre del dispositivo (puede llegar después de 0x2C)
            
            // Estas son respuestas válidas de inicialización, no errores
            // Retornar true para indicar que fueron procesadas correctamente
            if (key == 0x57 || key == 0x2C || key == 0x51) {
                android.util.Log.d("MkButtonSDK", "Init response received: 0x" + String.format("%02X", key));
                
                // Si es 0x51, extraer el nombre del dispositivo
                if (key == 0x51 && value.length > 3) {
                    int nameLength = value[3] & 0xFF;
                    if (value.length >= 4 + nameLength) {
                        try {
                            String deviceName = new String(value, 4, nameLength, "UTF-8");
                            android.util.Log.d("MkButtonSDK", "Device name: " + deviceName + " (0x51 response, may arrive delayed)");
                            android.util.Log.d("MkButtonSDK", "0x51 response handled successfully, returning true");
                        } catch (Exception e) {
                            android.util.Log.w("MkButtonSDK", "Failed to parse device name", e);
                        }
                    }
                }
                android.util.Log.d("MkButtonSDK", "Returning true for init response 0x" + String.format("%02X", key));
                return true;
            }
        }

        OrderCHAR orderCHAR = null;
        if (responseUUID.equals(OrderCHAR.CHAR_DISCONNECT.getUuid())) {
            orderCHAR = OrderCHAR.CHAR_DISCONNECT;
        }
        if (responseUUID.equals(OrderCHAR.CHAR_ACC.getUuid())) {
            orderCHAR = OrderCHAR.CHAR_ACC;
        }
        if (responseUUID.equals(OrderCHAR.CHAR_SINGLE_TRIGGER.getUuid())) {
            orderCHAR = OrderCHAR.CHAR_SINGLE_TRIGGER;
        }
        if (responseUUID.equals(OrderCHAR.CHAR_DOUBLE_TRIGGER.getUuid())) {
            orderCHAR = OrderCHAR.CHAR_DOUBLE_TRIGGER;
        }
        if (responseUUID.equals(OrderCHAR.CHAR_LONG_TRIGGER.getUuid())) {
            orderCHAR = OrderCHAR.CHAR_LONG_TRIGGER;
        }
        if (responseUUID.equals(OrderCHAR.CHAR_CLICK_EVENT.getUuid())) {
            android.util.Log.d("MkButtonSDK", "CHAR_CLICK_EVENT notification received, processing...");
            orderCHAR = OrderCHAR.CHAR_CLICK_EVENT;
        }
        if (responseUUID.equals(OrderCHAR.CHAR_LONG_CONNECTION.getUuid())) {
            orderCHAR = OrderCHAR.CHAR_LONG_CONNECTION;
        }
        if (orderCHAR == null)
            return false;
        XLog.i(orderCHAR.name());
        android.util.Log.d("MkButtonSDK", "Creating event for " + orderCHAR.name() + " with value: " + com.moko.ble.lib.utils.MokoUtils.bytesToHexString(value));
        OrderTaskResponse response = new OrderTaskResponse();
        response.orderCHAR = orderCHAR;
        response.responseValue = value;
        OrderTaskResponseEvent event = new OrderTaskResponseEvent();
        event.setAction(MokoConstants.ACTION_CURRENT_DATA);
        event.setResponse(response);
        EventBus.getDefault().post(event);
        android.util.Log.d("MkButtonSDK", "Event posted successfully for " + orderCHAR.name() + ", returning true");
        return true;
    }

    public void enableSingleTriggerNotify() {
        if (mBleConfig != null)
            mBleConfig.enableSingleTriggerNotify();
    }

    public void disableSingleTriggerNotify() {
        if (mBleConfig != null)
            mBleConfig.disableSingleTriggerNotify();
    }

    public void enableDoubleTriggerNotify() {
        if (mBleConfig != null)
            mBleConfig.enableDoubleTriggerNotify();
    }

    public void disableDoubleTriggerNotify() {
        if (mBleConfig != null)
            mBleConfig.disableDoubleTriggerNotify();
    }

    public void enableLongTriggerNotify() {
        if (mBleConfig != null)
            mBleConfig.enableLongTriggerNotify();
    }

    public void disableLongTriggerNotify() {
        if (mBleConfig != null)
            mBleConfig.disableLongTriggerNotify();
    }

    public void enableAccNotify() {
        if (mBleConfig != null)
            mBleConfig.enableAccNotify();
    }

    public void disableAccNotify() {
        if (mBleConfig != null)
            mBleConfig.disableAccNotify();
    }

    public void enableClickEventNotify() {
        if (mBleConfig != null)
            mBleConfig.enableClickEventNotify();
    }

    public void disableClickEventNotify() {
        if (mBleConfig != null)
            mBleConfig.disableClickEventNotify();
    }

    public void enableLongConnectionNotify() {
        if (mBleConfig != null)
            mBleConfig.enableLongConnectionNotify();
    }

    public void disableLongConnectionNotify() {
        if (mBleConfig != null)
            mBleConfig.disableLongConnectionNotify();
    }

    public ArrayList<ExportData> exportSingleEvents;
    public StringBuilder storeSingleEventString;
    public ArrayList<ExportData> exportDoubleEvents;
    public StringBuilder storeDoubleEventString;
    public ArrayList<ExportData> exportLongEvents;
    public StringBuilder storeLongEventString;
    public ArrayList<ExportData> exportLongConnectionEvents;
    public StringBuilder storeLongConnectionEventString;
}
